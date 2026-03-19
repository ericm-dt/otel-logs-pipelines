# Fetch an auth token for the EKS cluster to authenticate the Kubernetes and Helm providers.
data "aws_eks_cluster_auth" "primary" {
  name = aws_eks_cluster.primary.name
}

# Discover the available AZs in the selected region.
data "aws_availability_zones" "available" {
  state = "available"
}

# Data sources for selecting existing/default VPCs.
data "aws_vpc" "default" {
  count   = var.vpc_cidr == null && var.existing_vpc_id == null ? 1 : 0
  default = true
}

data "aws_vpc" "selected" {
  count = var.existing_vpc_id != null ? 1 : 0
  id    = var.existing_vpc_id
}

# Local to simplify subnet and VPC selection logic.
locals {
  create_custom_vpc = var.vpc_cidr != null
  use_existing_vpc  = !local.create_custom_vpc
  create_project_subnets = local.create_custom_vpc || (
    var.public_subnet_cidrs != null && var.private_subnet_cidrs != null
  )

  vpc_id = local.create_custom_vpc ? aws_vpc.main[0].id : (
    var.existing_vpc_id != null ? data.aws_vpc.selected[0].id : data.aws_vpc.default[0].id
  )

  effective_public_subnet_cidrs = var.public_subnet_cidrs != null ? var.public_subnet_cidrs : (
    local.create_custom_vpc ? [cidrsubnet(var.vpc_cidr, 8, 0), cidrsubnet(var.vpc_cidr, 8, 1)] : []
  )
  effective_private_subnet_cidrs = var.private_subnet_cidrs != null ? var.private_subnet_cidrs : (
    local.create_custom_vpc ? [cidrsubnet(var.vpc_cidr, 8, 10), cidrsubnet(var.vpc_cidr, 8, 11)] : []
  )
}

# Existing subnets are used only when dedicated project subnets are not requested.
data "aws_subnets" "existing" {
  count = local.use_existing_vpc && !local.create_project_subnets ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

# Discover the existing IGW for the selected VPC when using existing/default VPC.
data "aws_internet_gateway" "existing" {
  count = local.use_existing_vpc && local.create_project_subnets ? 1 : 0
  filter {
    name   = "attachment.vpc-id"
    values = [local.vpc_id]
  }
}

locals {
  subnet_ids = local.create_project_subnets ? concat(
    aws_subnet.public[*].id,
    aws_subnet.private[*].id
  ) : slice(data.aws_subnets.existing[0].ids, 0, 2)

  node_subnet_ids = local.create_project_subnets ? aws_subnet.private[*].id : slice(data.aws_subnets.existing[0].ids, 0, 2)
  internet_gateway_id = local.create_project_subnets ? (
    local.create_custom_vpc ? aws_internet_gateway.main[0].id : data.aws_internet_gateway.existing[0].id
  ) : null
}

# ---------------------------------------------------------------------------
# VPC – Optional custom VPC
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  count                = local.create_custom_vpc ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = var.cluster_name }
}

resource "aws_internet_gateway" "main" {
  count  = local.create_custom_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = { Name = var.cluster_name }
}

# Public subnets – used by load balancers and the NAT gateway.
resource "aws_subnet" "public" {
  count                   = local.create_project_subnets ? length(local.effective_public_subnet_cidrs) : 0
  vpc_id                  = local.vpc_id
  cidr_block              = local.effective_public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.cluster_name}-public-${count.index}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Private subnets – used by worker nodes.
resource "aws_subnet" "private" {
  count             = local.create_project_subnets ? length(local.effective_private_subnet_cidrs) : 0
  vpc_id            = local.vpc_id
  cidr_block        = local.effective_private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

  tags = {
    Name                                        = "${var.cluster_name}-private-${count.index}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# NAT gateway (single, in first public subnet) so private nodes can reach the internet.
resource "aws_eip" "nat" {
  count  = local.create_project_subnets ? 1 : 0
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  count         = local.create_project_subnets ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = { Name = var.cluster_name }

}

# Route table for public subnets.
resource "aws_route_table" "public" {
  count  = local.create_project_subnets ? 1 : 0
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = local.internet_gateway_id
  }

  tags = { Name = "${var.cluster_name}-public" }
}

resource "aws_route_table_association" "public" {
  count          = local.create_project_subnets ? length(aws_subnet.public) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Route table for private subnets (egress via NAT).
resource "aws_route_table" "private" {
  count  = local.create_project_subnets ? 1 : 0
  vpc_id = local.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = { Name = "${var.cluster_name}-private" }
}

resource "aws_route_table_association" "private" {
  count          = local.create_project_subnets ? length(aws_subnet.private) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# ---------------------------------------------------------------------------
# IAM – EKS cluster role
# ---------------------------------------------------------------------------

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# ---------------------------------------------------------------------------
# EKS cluster
# ---------------------------------------------------------------------------

resource "aws_eks_cluster" "primary" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  upgrade_policy {
    support_type = "STANDARD"
  }

  vpc_config {
    subnet_ids              = local.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# ---------------------------------------------------------------------------
# IAM – node group role
# ---------------------------------------------------------------------------

resource "aws_iam_role" "nodes" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

# ---------------------------------------------------------------------------
# EKS managed node group
# ---------------------------------------------------------------------------

resource "aws_eks_node_group" "primary" {
  cluster_name    = aws_eks_cluster.primary.name
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = local.node_subnet_ids
  instance_types  = [var.instance_type]
  disk_size       = var.disk_size_gb

  scaling_config {
    desired_size = var.node_count
    min_size     = 1
    # Allow the node group to scale up to double the desired count for headroom.
    max_size = var.node_count * 2
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker_policy,
    aws_iam_role_policy_attachment.nodes_cni_policy,
    aws_iam_role_policy_attachment.nodes_ecr_policy,
  ]
}
