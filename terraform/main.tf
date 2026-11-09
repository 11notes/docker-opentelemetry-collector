terraform {
  required_version = ">= 1.15.0"
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "~> 3.2"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

resource "kubernetes_namespace_v1" "opentelemetry_collector" {
  metadata {
    name = "opentelemetry-collector"
  }
}

variable "ingress_ip" {
  type = string
}

variable "hec_url" {
  type = string
}

variable "hec_token" {
  type = string
  sensitive = true
}

resource "kubernetes_secret_v1" "hec_token" {
  metadata {
    name = "hec-token"
    namespace = "opentelemetry-collector"
  }

  data = {
    HEC_TOKEN = trimspace(var.hec_token)
  }

  type = "Opaque"
}

resource "kubernetes_service_v1" "opentelemetry_collector_service" {
  metadata {
    name = "opentelemetry-collector-service"
    namespace = "opentelemetry-collector"
    annotations = {
      "metallb.io/loadBalancerIPs" = trimspace(var.ingress_ip)
      "metallb.io/allow-shared-ip" = "default"
    }
  }
  spec {
    type = "LoadBalancer"
    external_traffic_policy = "Local"
    selector = {
      "app.kubernetes.io/instance" = "opentelemetry-collector"
      "app.kubernetes.io/name" = "opentelemetry-collector"
    }
    port {
      name = "syslog-tcp"
      protocol = "TCP"
      port = 5141
      target_port = 5140
    }
    port {
      name = "syslog-udp"
      protocol = "UDP"
      port = 5141
      target_port = 5140
    }
  }
}

resource "helm_release" "opentelemetry_collector" {
  name = "opentelemetry-collector"
  repository = "oci://ghcr.io/11notes/charts"
  chart = "opentelemetry-collector"
  namespace = "opentelemetry-collector"
  version = "0.0.1"

  wait = true
  wait_for_jobs = true
  timeout = 300

  values = [
    yamlencode({
      image = {
        tag = "0.158.0"
      }
      extraEnv = [
        {
          name = "HEC_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = "hec-token"
              key  = "HEC_TOKEN"
            }
          }
        },
        {
          name = "HEC_URL"
          value = trimspace(var.hec_url)
        }
      ]
    })
  ]
}