provider "aws" {
	region = var.region
}

terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "eks_state"
    region = "us-east-1"
  }
}

resource "aws_eks_cluster" "cluster" {
  name       = var.cluster_name
  role_arn   = aws_iam_role.cluster_role.arn

  vpc_config {
    subnet_ids = concat(var.public_subnet_ids, var.private_subnet_ids)
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_policy,
    aws_iam_role_policy_attachment.eks_resource_policy
  ]
}

resource "aws_iam_role" "cluster_role" {
  name               = "${var.cluster_name}_role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_resource_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster_role.name
}
