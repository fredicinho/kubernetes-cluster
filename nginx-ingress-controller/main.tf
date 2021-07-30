provider "helm" {
  kubernetes {
    config_path = var.kubectl_config_path
    config_context = var.kubectl_config_context
  }
}

resource "helm_release" "ingress_controller" {
  name             = "nginx-ingress-controller-v1"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  create_namespace = "true"
  namespace        = "ingress-nginx"

  values = [
    "${file("values.yaml")}"
  ]
}


