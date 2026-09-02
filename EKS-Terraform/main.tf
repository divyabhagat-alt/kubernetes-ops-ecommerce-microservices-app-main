terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

############################
# PROVIDER
############################

provider "aws" {
  region = "us-west-2"
}

############################
# VARIABLES
############################

variable "cluster_version" {
  default = "1.31"
}

############################
# GET LATEST AMAZON LINUX 2 AMI
############################

data "aws_ssm_parameter" "sd_amazon_linux" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

############################
# VPC
############################

resource "aws_vpc" "sd_vpc" {

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "sd-vpc"
  }
}

resource "aws_internet_gateway" "sd_igw" {

  vpc_id = aws_vpc.sd_vpc.id

  tags = {
    Name = "sd-igw"
  }
}

############################
# SUBNETS
############################

resource "aws_subnet" "sd_public1" {

  vpc_id                  = aws_vpc.sd_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "sd-public-subnet-1"
  }
}

resource "aws_subnet" "sd_public2" {

  vpc_id                  = aws_vpc.sd_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "sd-public-subnet-2"
  }
}

resource "aws_subnet" "sd_private1" {

  vpc_id            = aws_vpc.sd_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-west-2a"

  tags = {
    Name = "sd-private-subnet-1"
  }
}

resource "aws_subnet" "sd_private2" {

  vpc_id            = aws_vpc.sd_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-west-2b"

  tags = {
    Name = "sd-private-subnet-2"
  }
}

############################
# NAT GATEWAY
############################

resource "aws_eip" "sd_nat_eip" {

  domain = "vpc"

  tags = {
    Name = "sd-nat-eip"
  }
}

resource "aws_nat_gateway" "sd_nat" {

  allocation_id = aws_eip.sd_nat_eip.id
  subnet_id     = aws_subnet.sd_public1.id

  tags = {
    Name = "sd-nat-gateway"
  }

  depends_on = [aws_internet_gateway.sd_igw]
}

############################
# ROUTE TABLES
############################

resource "aws_route_table" "sd_public_rt" {

  vpc_id = aws_vpc.sd_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.sd_igw.id
  }

  tags = {
    Name = "sd-public-route-table"
  }
}

resource "aws_route_table_association" "sd_pub1_assoc" {

  subnet_id      = aws_subnet.sd_public1.id
  route_table_id = aws_route_table.sd_public_rt.id
}

resource "aws_route_table_association" "sd_pub2_assoc" {

  subnet_id      = aws_subnet.sd_public2.id
  route_table_id = aws_route_table.sd_public_rt.id
}

resource "aws_route_table" "sd_private_rt" {

  vpc_id = aws_vpc.sd_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.sd_nat.id
  }

  tags = {
    Name = "sd-private-route-table"
  }
}

resource "aws_route_table_association" "sd_priv1_assoc" {

  subnet_id      = aws_subnet.sd_private1.id
  route_table_id = aws_route_table.sd_private_rt.id
}

resource "aws_route_table_association" "sd_priv2_assoc" {

  subnet_id      = aws_subnet.sd_private2.id
  route_table_id = aws_route_table.sd_private_rt.id
}

############################
# SECURITY GROUP
############################

resource "aws_security_group" "sd_allow_all" {

  name        = "sd-allow-all-sg"
  description = "Allow all inbound and outbound traffic"
  vpc_id      = aws_vpc.sd_vpc.id

  ingress {

    description = "Allow all inbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {

    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sd-allow-all-sg"
  }
}

############################
# IAM ROLE - CLUSTER
############################

resource "aws_iam_role" "sd_cluster_role" {

  name = "sd-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sd_cluster_policy" {

  role       = aws_iam_role.sd_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

############################
# IAM ROLE - NODE GROUP
############################

resource "aws_iam_role" "sd_worker_role" {

  name = "sd-eks-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sd_worker_node" {

  role       = aws_iam_role.sd_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "sd_cni" {

  role       = aws_iam_role.sd_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "sd_ecr" {

  role       = aws_iam_role.sd_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

############################
# EKS CLUSTER
############################

resource "aws_eks_cluster" "sd_eks" {

  name     = "sd-eks-cluster"
  role_arn = aws_iam_role.sd_cluster_role.arn
  version  = var.cluster_version

  vpc_config {

    subnet_ids = [
      aws_subnet.sd_private1.id,
      aws_subnet.sd_private2.id
    ]

    endpoint_public_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.sd_cluster_policy
  ]

  tags = {
    Name = "sd-eks-cluster"
  }
}

############################
# NODE GROUP
############################

resource "aws_eks_node_group" "sd_node_group" {

  cluster_name    = aws_eks_cluster.sd_eks.name
  node_group_name = "sd-node-group"

  node_role_arn = aws_iam_role.sd_worker_role.arn
  version       = var.cluster_version

  subnet_ids = [
    aws_subnet.sd_private1.id,
    aws_subnet.sd_private2.id
  ]

  instance_types = ["t3.medium"]

  scaling_config {

    desired_size = 6
    max_size     = 6
    min_size     = 6
  }

  depends_on = [
    aws_iam_role_policy_attachment.sd_worker_node,
    aws_iam_role_policy_attachment.sd_cni,
    aws_iam_role_policy_attachment.sd_ecr
  ]

  tags = {
    Name        = "sd-eks-node"
    Environment = "dev"
    Project     = "sd-eks-project"
    Owner       = "veeraops"
  }
}

############################
# BASTION SERVER
############################

resource "aws_instance" "sd_bastion" {

  ami                    = data.aws_ssm_parameter.sd_amazon_linux.value
  instance_type          = "t2.medium"
  subnet_id              = aws_subnet.sd_public1.id
  vpc_security_group_ids = [aws_security_group.sd_allow_all.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
  }

  tags = {
    Name = "sd-bastion"
  }

  user_data = <<-EOF
              #!/bin/bash

              yum update -y

              # Install kubectl
              curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-09-12/bin/linux/amd64/kubectl

              chmod +x ./kubectl
              mv ./kubectl /usr/local/bin

              # Install eksctl
              curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

              mv /tmp/eksctl /usr/local/bin

              # Install AWS CLI
              yum install -y unzip

              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

              unzip awscliv2.zip

              ./aws/install
              EOF
}

############################
# EKS ADDONS
############################

resource "aws_eks_addon" "sd_vpc_cni" {

  cluster_name = aws_eks_cluster.sd_eks.name
  addon_name   = "vpc-cni"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.sd_node_group]
}

resource "aws_eks_addon" "sd_coredns" {

  cluster_name = aws_eks_cluster.sd_eks.name
  addon_name   = "coredns"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.sd_node_group]
}

resource "aws_eks_addon" "sd_kube_proxy" {

  cluster_name = aws_eks_cluster.sd_eks.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.sd_node_group]
}

resource "aws_eks_addon" "sd_pod_identity" {

  cluster_name = aws_eks_cluster.sd_eks.name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.sd_node_group]
}

############################
# EBS CSI DRIVER
############################

resource "aws_iam_role" "sd_ebs_csi_role" {

  name = "sd-amazon-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "sd_ebs_csi_policy" {

  role       = aws_iam_role.sd_ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_pod_identity_association" "sd_ebs_csi_assoc" {

  cluster_name    = aws_eks_cluster.sd_eks.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"

  role_arn = aws_iam_role.sd_ebs_csi_role.arn

  depends_on = [
    aws_iam_role_policy_attachment.sd_ebs_csi_policy
  ]
}

resource "aws_eks_addon" "sd_ebs_csi" {

  cluster_name                = aws_eks_cluster.sd_eks.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.sd_node_group,
    aws_eks_pod_identity_association.sd_ebs_csi_assoc
  ]
}