# CLAUDE.md

Guidance for Claude Code (and other agents) working in this repository.

## What this is

`osm-app` — a small "what's nearby" map search tool over OpenStreetMap data — deployed on
AWS EKS. The repo has two halves:

- **`infra/`** — Terraform IaC for the AWS/Kubernetes platform the app runs on.
  **Non-negotiable rule: `terraform apply`/`destroy` are human-only** — never run them
  yourself from an agent session.
- **`osm-app/`** — the application source. Three services (`frontend`, `fetcher`,
  `history`) plus `postgres`/`rabbitmq`/`redis`. Runnable standalone via
  `osm-app/compose.yaml` (docker/podman compose) for local dev, **or** deployed onto the
  `infra/k8s/` cluster — the two paths differ (see "Local dev vs. k8s" below).

Both halves share one git history (merged from previously separate repos); `osm-app`'s two
Rust services used to be git submodules, now plain tracked files under
`osm-app/overpass-api-fetcher/osm-fetcher/` and `osm-app/history/osm-history/`.

## Architecture (as deployed on k8s)

```
                         Cloudflare (DNS, proxied)
                                   │
                                   ▼
                    AWS NLB  (infra/k8s: Envoy Gateway's
                              Service, provisioned via EnvoyProxy CR)
                                   │
                                   ▼
                    Envoy Gateway  (Gateway API: Gateway "main-gateway"
                              in ns envoy-gw, HTTPRoute "osm-app" in ns osm-app)
                           ┌───────┴───────┐
                    PathPrefix /       PathPrefix /api
                           │                  │
                           ▼                  ▼
                 S3 static website      Service "fetcher" (ns osm-app)
                 (frontend bucket,            │
                  via Envoy Backend CRD)      ├─ RabbitMQ (history.events queue)
                                               ├─ Redis (response cache + rate limit)
                                               └─ Overpass API (public internet)

                 Service "history" (ns osm-app) ── consumes history.events ── Postgres
```

Key point: **there is no nginx anywhere in the k8s path.** The old `osm-app/frontend`
nginx container (which used to both serve static files and reverse-proxy `/api/`) has been
replaced entirely by Envoy Gateway doing both jobs natively:
- static frontend files are uploaded straight to an S3 bucket (`infra/k8s/frontend.tf`,
  `fileset()` over `osm-app/frontend/`) and served via an Envoy `Backend` CRD +
  `URLRewrite` filter — the same mechanism the old placeholder demo site used.
- `/api/*` is routed directly to the `fetcher` Kubernetes `Service` via a plain Gateway API
  `backendRef` (no `Backend` CRD needed — that's only for non-Service targets like the S3
  endpoint above).

`osm-app/frontend/Dockerfile` / `nginx.conf.template` / `15-resolver.envsh` still exist and
still work for local `docker compose`/`podman-compose` — they're just unused by the
Terraform/k8s deployment path. Don't "fix" them to match k8s; they're a separate, valid
workflow.

## Terraform layout

Three independent root modules in `infra/`, each with its own S3-backed state, applied in
order `vpc/ → eks/ → k8s/`. Almost all app-level work happens in `infra/k8s/`:

| File(s) | What |
|---|---|
| `namespaces.tf`, `vars.tf` | `osm-app` namespace; app-level vars (image tags, Overpass endpoint, postgres/rabbitmq default creds) |
| `secrets.tf` | `kubernetes_secret_v1` for postgres/rabbitmq creds (never plain env on Deployments) |
| `postgres.tf`, `rabbitmq.tf`, `redis.tf` | native `kubernetes_deployment_v1`/`kubernetes_service_v1`, 1 replica each, `emptyDir` (no PVC — **no `aws-ebs-csi-driver` addon on the EKS cluster**, so a PVC would stay `Pending`; data loss on pod reschedule is an accepted tradeoff for now) |
| `fetcher.tf`, `history.tf` | the two app services, 2 replicas each, images from `ecr.tf`'s repos |
| `ecr.tf`, `outputs.tf` | ECR repos for `fetcher`/`history`; outputs consumed by `push-images.sh` |
| `frontend.tf` | S3 bucket + website config + `aws_s3_object` per real frontend file (via `fileset()`, excluding the Dockerfile/compose-only files) |
| `routing.tf` + `manifests/frontend/*.yml` | the `Backend` CRD and `HTTPRoute` described above |
| `push-images.sh` | build+push `fetcher`/`history` images to ECR; auto-detects `podman` or `docker` |
| `gateway.tf`, `cert-manager.tf`, `external-dns.tf` | pre-existing ingress/TLS/DNS control plane, not osm-app-specific — see gotchas below before touching these |

## The "shard" rule

In this project, **"a shard" = one of the three Terraform root modules** (`vpc`, `eks`, or
`k8s`) — not a Kubernetes concept. Each one has its own live state. Before editing `.tf`
code inside a module that already has applied state, say so explicitly and wait for the
human to run `terraform destroy` in that module themselves (you never run `apply` or
`destroy`). In practice almost all work so far has stayed inside the `k8s` module; `vpc`
and `eks` are touched rarely and should stay that way unless there's a specific reason.

## Local dev vs. k8s deployment

| | local (`docker compose`/`podman-compose up`) | k8s (`infra/k8s/`) |
|---|---|---|
| frontend | nginx container, serves static + proxies `/api/` | no container — static files in S3, Envoy routes `/api/` |
| fetcher/history images | built from `Dockerfile` by compose | built/pushed by `push-images.sh` to ECR |
| postgres/rabbitmq/redis | named volumes (persistent) | `emptyDir` (ephemeral) |
| creds | `history`/`history`, `app`/`app` defaults in `compose.yaml` | same defaults, but via `vars.tf` → `kubernetes_secret_v1` |

Both are valid; don't assume one when debugging something reported about the other.

## Monitoring (k8s only)

Namespace `monitoring`, all in `infra/k8s/` (`loki.tf`, `mimir.tf`, `otel-collector.tf`,
`grafana.tf`, `monitoring-storage.tf`; config templates in `monitoring/*.tftpl`):

```
pod stdout ─► otel-agent (DaemonSet: filelog + kubeletstats) ─► Loki  (OTLP)        ─┐
envoy / rabbitmq / redis / postgres / k8s state                                      ├─► S3
   └► otel-gateway (Deployment x1) ─────────────────────────► Mimir (remote write) ─┘
                                            Grafana (datasources Mimir + Loki)
```

- **Grafana is not exposed.** Access: `kubectl port-forward -n monitoring svc/grafana 3000:80`
  (user `admin`, password from `var.grafana_admin_password`, default `admin`). Publishing it
  needs TLS for a subdomain, which is unresolved: `main-gateway`'s HTTPS listener has no `hostname`.
- **Storage is S3 via EKS Pod Identity** (one bucket + IAM role per component, no static keys),
  because there is no EBS CSI driver. Loki/Mimir/Grafana pods use `emptyDir` for local state.
- **Mimir is a native single-pod Deployment (`-target=all`), not the `mimir-distributed` chart**
  (that chart deploys 10+ pods and doesn't fit). Its S3 config needs
  `native_aws_auth_enabled: true`, otherwise Pod Identity credentials aren't picked up.
  Loki uses the `grafana/loki` chart in `SingleBinary` mode.
- **Grafana chart comes from `grafana-community/helm-charts`** — the one in `grafana/helm-charts`
  is deprecated. Dashboards: drop a JSON file into `infra/k8s/monitoring/dashboards/`; each file
  becomes a labelled ConfigMap picked up by the sidecar.
- **Scrape targets:** any `osm-app` pod annotated `prometheus.io/scrape=true` (+ `port`, `path`) —
  RabbitMQ (`:15692`) is annotated; `fetcher`/`history` have no `/metrics` yet. Redis and Postgres are
  read by the collector's own receivers (no exporters). Envoy proxy pods in `envoy-gw` are scraped on
  `:19001/stats/prometheus` — these Envoy details and the `rabbitmq_prometheus` plugin were not
  verified against a live cluster; confirm after the first deploy.
- **`templatefile()` pitfalls in `monitoring/*.tftpl`:** write collector env references with a doubled
  `$` and relabel `$1` as `$$1`; never put a literal interpolation sequence in a *comment* either —
  `templatefile()` parses it and fails `terraform validate`.
- The node group is `t3.medium` (was `t3.small`, which ran out of pod slots). Collector resource
  limits and pod counts are estimates — check `kubectl top pods -A` / `kubectl describe nodes`.

## Deployment workflow (k8s)

1. Edit `.tf`/`.yml` under `infra/k8s/` (respecting the shard rule above).
2. Human runs `terraform plan` / `terraform apply` in `infra/k8s/` themselves.
3. Human (or you, if asked — it's a plain script, not Terraform) runs
   `infra/k8s/push-images.sh` to build+push `fetcher`/`history` to ECR. Until pushed,
   those pods sit in `ImagePullBackOff` — expected and harmless.
4. `kubectl rollout restart deployment/fetcher deployment/history -n osm-app` after a
   first push (or any later push — `:latest` + `MUTABLE` tags don't trigger an automatic
   rollout on their own).
5. Verify via `kubectl get pods -n osm-app`, `curl https://<domain>/` and
   `.../api/query`, not by reading Terraform output alone — several of the bugs below only
   showed up at the HTTP level.

## Gotchas already hit (don't rediscover these)

These are hard-won from actually deploying this stack, not theoretical:

- **`wait_for_rollout` on every app `kubernetes_deployment_v1`** (`postgres.tf`,
  `rabbitmq.tf`, `redis.tf`, `fetcher.tf`, `history.tf`) is explicitly `false`. Without it,
  `terraform apply` blocks until pods are `Ready` — which can't happen for `fetcher`/
  `history` before their images exist in ECR — and a long-hanging `apply` reliably outlives
  short-lived AWS credentials/EKS auth tokens, causing confusing mid-apply failures
  (`Unauthorized`, `failed to upload state`). Check readiness separately with `kubectl`.
- **RabbitMQ's liveness/readiness probe needs `timeout_seconds = 10`.** The default `1s`
  exec-probe timeout is too short for `rabbitmq-diagnostics -q ping` (it spins up a
  separate Erlang CLI process) on a loaded `t3.small` node — RabbitMQ actually boots fine,
  then gets `SIGTERM`'d by kubelet ~45s later and loops.
- **The `external-dns` Helm chart has no structured `cloudflare.proxied` value** in this
  chart version — only `extraArgs` (rendered as raw CLI flags). Use
  `{ name = "extraArgs.cloudflare-proxied", value = "true" }`, not
  `{ name = "cloudflare.proxied", ... }` (the latter is silently ignored).
- **`external-dns` won't fix an existing record's `proxied` flag on its own.** Its
  reconcile loop only acts on records it considers out of date by *content*; a
  `proxied: false → true` change to an otherwise-identical record is never applied to a
  pre-existing record. If you change that setting, you may need to flip the existing
  record once via the Cloudflare API (or delete it so `external-dns` recreates it from
  scratch) — "All records are already up to date" in its logs does not mean the live
  record matches your current config.
- **A stale, manually-created DNS record can silently shadow everything.** `external-dns`
  runs with `policy=upsert-only` and only touches records it owns via its TXT registry
  (`txtOwnerId`); a pre-existing CNAME it doesn't own (e.g. an old direct-to-S3 record from
  before Envoy Gateway existed) is left alone forever. Symptom: requests succeed but
  clearly never reach the cluster (e.g. `/api/*` 404/405ing with S3-shaped error bodies,
  `x-amz-request-id` headers, even though Envoy's own `/config_dump` and `/clusters` show
  completely correct routing). Check actual DNS records via the Cloudflare API, not just
  the HTTPRoute's `status` conditions.
- **Envoy Gateway's default per-route timeout (15s) is too short for Overpass API
  queries.** The old nginx config had `proxy_read_timeout 300s` for exactly this reason;
  the `/api` `HTTPRoute` rule needs an explicit `timeouts.request: 300s`.
- **`eks/main.tf`'s `endpoint_public_access_cidrs` is derived from `https://ifconfig.me/ip`
  at plan/apply time.** On an IPv6-preferring network (e.g. many mobile carriers),
  `ifconfig.me` returns an IPv6 address, and the hardcoded `/32` suffix produces an invalid
  CIDR, hard-failing *any* plan/apply/destroy in that module. Fixed by switching to
  `https://api.ipify.org` (IPv4-only, no `AAAA` record) — don't revert this without
  checking why.
- **No `aws-ebs-csi-driver` EKS addon exists.** Don't add a `PersistentVolumeClaim`
  anywhere in `k8s/` expecting it to bind — it'll sit `Pending` forever until that addon
  (and associated IAM) is added, which is a deliberately deferred `eks/`-module change.
- **`osm-app/compose.yaml`'s `build: ./overpass-api-fetcher` (and the `history`
  equivalent) point one directory too shallow** — the real `Dockerfile`s are nested one
  level deeper, at `osm-app/overpass-api-fetcher/osm-fetcher/Dockerfile` and
  `osm-app/history/osm-history/Dockerfile`. `push-images.sh` already uses the correct
  nested paths; local `docker compose build` may not work as-is. Not yet fixed — flag it
  rather than silently working around it if it comes up again.

## Conventions

- Terraform comments are in Ukrainian, matching the existing convention in `infra/` —
  keep doing that in `infra/k8s/*.tf`.
- Prefer native `kubernetes_*` Terraform resources (Deployment, Service, Secret,
  Namespace) over `kubectl_manifest` + YAML for anything the `kubernetes` provider models
  natively. Reserve `kubectl_manifest` (`manifests/<component>/*.yml`, loaded via `file()`
  or `templatefile()`) for Gateway API / CRD objects the provider doesn't support
  (`Backend`, `HTTPRoute`, `ClusterIssuer`, etc.) — this is the existing split in the repo,
  don't blur it.
