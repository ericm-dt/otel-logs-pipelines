terraform {
  required_version = ">= 1.5.0"

  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = ">= 1.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "dynatrace" {
  dt_env_url   = var.dt_tenant_url
  dt_api_token = var.dt_operator_api_token != null ? var.dt_operator_api_token : var.dt_api_token
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
