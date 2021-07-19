terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/visol-kubeconfig.yml"
  }
}

provider "kubectl" {
  config_path = "~/.kube/visol-kubeconfig.yml"
}

provider "kubernetes" {
  config_path = "~/.kube/visol-kubeconfig.yml"
}

provider "kubernetes-alpha" {
  config_path = "~/.kube/visol-kubeconfig.yml"
}

# https://github.com/hashicorp/terraform-provider-kubernetes-alpha/issues/72
#resource "kubectl_manifest" "cert-manager-crd" {
#  yaml_body = file("${path.module}/cert-manager-crd.yml")
#}


# Could use Terraform helm chart: https://github.com/basisai/terraform-helm-cert-manager
resource "helm_release" "certmanager" {
  name      = "cert-manager-v1"
  chart     = "jetstack/cert-manager"
  namespace = "cert-manager"
}

resource "kubernetes_secret" "cloudflare-api-key" {
  metadata {
    name      = "cloudflare-api-key"
    namespace = "cert-manager"
  }

  data = {
    api-key = var.cloudflare_api_key
  }
}

resource "kubernetes_manifest" "letsencrypt-prod" {
  provider = kubernetes-alpha

  manifest = {
    apiVersion = "cert-manager.io/v1alpha2"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = "fredae14@hotmail.com"
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [{
          dns01 = {
            cloudflare = {
              email = "fredae14@hotmail.com"
              apiKeySecretRef = {
                name = "cloudflare-api-key"
                key  = "api-key"
              }
            }
          }
        }]
      }
    }
  }

  depends_on = [
    helm_release.certmanager
  ]
}

resource "kubernetes_service_account" "sa-cert-manager-cronjob" {
  metadata {
    name      = "sa-cert-manager-cronjob"
    namespace = "cert-manager"
  }
  depends_on = [helm_release.certmanager]
}

resource "kubernetes_cluster_role_binding" "cluster-rolebinding-cronjob" {
  metadata {
    name = "cluster-rolebinding-cronjob"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "sa-cert-manager-cronjob"
    namespace = "cert-manager"
  }

  depends_on = [
    kubernetes_service_account.sa-cert-manager-cronjob
  ]
}

resource "kubernetes_manifest" "certificate-wildcard-mydomain-dev" {
  provider = kubernetes-alpha

  manifest = {
    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Certificate"
    "metadata" = {
      "name"      = "wildcard.mydomain.dev"
      "namespace" = "cert-manager"
    }
    "spec" = {
      "dnsNames" = [
        "*.mydomain.dev",
      ]
      "issuerRef" = {
        "kind" = "ClusterIssuer"
        "name" = "letsencrypt-prod"
      }
      "secretName" = "wildcard.mydomain.dev"
    }
  }

  depends_on = [
    kubernetes_service_account.sa-cert-manager-cronjob,
    helm_release.certmanager,
    kubernetes_manifest.letsencrypt-prod
  ]
}

resource "kubernetes_manifest" "cronjob_cert_manager_cronjob" {
  provider = kubernetes-alpha

  manifest = {
    "apiVersion" = "batch/v1beta1"
    "kind"       = "CronJob"
    "metadata" = {
      "name"      = "cert-manager-cronjob"
      "namespace" = "cert-manager"
    }
    "spec" = {
      "jobTemplate" = {
        "spec" = {
          "template" = {
            "spec" = {
              "containers" = [
                {
                  "args" = [
                    "for i in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do kubectl get secret -o yaml --namespace cert-manager wildcard.cmtbj9qp.visol.dev | sed 's/namespace: cert-manager//' | kubectl apply -n $${i} -f -;  done",
                  ]
                  "command" = [
                    "/bin/bash",
                    "-c",
                  ]
                  "image" = "bitnami/kubectl:latest"
                  "name"  = "hyperkube"
                },
              ]
              "restartPolicy"      = "Never"
              "serviceAccountName" = "sa-cert-manager-cronjob"
            }
          }
        }
      }
      "schedule" = "*/1 * * * *"
    }
  }

  depends_on = [
    kubernetes_manifest.certificate-wildcard-mydomain-dev
  ]
}










