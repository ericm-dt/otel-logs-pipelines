terraform {
  required_version = ">= 1.5.0"

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
  }
}

provider "aws" {
  region = var.region
}

# These providers are configured after the cluster is created, using the
# cluster's endpoint and CA certificate from the aws_eks_cluster resource.
provider "kubernetes" {
  host                   = aws_eks_cluster.primary.endpoint
  token                  = data.aws_eks_cluster_auth.primary.token
  cluster_ca_certificate = base64decode(aws_eks_cluster.primary.certificate_authority[0].data)
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.primary.endpoint
    token                  = data.aws_eks_cluster_auth.primary.token
    cluster_ca_certificate = base64decode(aws_eks_cluster.primary.certificate_authority[0].data)
  }
}
