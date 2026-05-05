terraform {
  required_version = ">= 1.5.0"

  # S3 is the preferred backend for shared/persistent use.
  # To use it: terraform init -backend-config=backend.tfvars
  # To use local state without editing this file: terraform init -backend=false
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    bindplane = {
      source  = "observIQ/bindplane"
      version = "~> 1.8"
    }
  }
}

provider "aws" {
  region = var.region
}

# These providers are configured after the cluster is created, using the
# cluster's endpoint and CA certificate from the aws_eks_cluster resource.
provider "kubernetes" {
  host                   = aws_eks_cluster.primary.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.primary.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.primary.name,
      "--region",
      var.region,
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.primary.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.primary.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.primary.name,
        "--region",
        var.region,
      ]
    }
  }
}

provider "bindplane" {
  remote_url      = var.bindplane_provider_remote_url
  api_key         = var.bindplane_provider_api_key
  username        = var.bindplane_provider_username
  password        = var.bindplane_provider_password
  tls_skip_verify = var.bindplane_provider_tls_skip_verify
}
