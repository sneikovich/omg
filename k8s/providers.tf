provider "helm" {
  kubernetes = {
    config_path = var.k8s_path
  }
}

provider "kubernetes" {
  config_path = var.k8s_path
  #  config_context = 
}
