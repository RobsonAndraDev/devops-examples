locals {
  bi_node = templatefile("${path.module}/userdata.tpl", {
    node_group_name = "bi_node",
    label           = "bi"
    cluster_ca      = aws_eks_cluster.cluster.certificate_authority[0].data
    api_url         = aws_eks_cluster.cluster.endpoint
    instance_type   = data.aws_ssm_parameter.ami.value
    efs             = aws_efs_file_system.bi_efs.dns_name
  })
}

resource "aws_efs_file_system" "bi_efs" {
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "${var.cluster_name}_bi_nodes"
  }
}

resource "aws_efs_mount_target" "bi_subnet1" {
  file_system_id  = aws_efs_file_system.bi_efs.id
  subnet_id       = var.public_subnet_ids[0]
  security_groups = [aws_security_group.bi_efs.id]
}

resource "aws_efs_mount_target" "bi_subnet2" {
  file_system_id = aws_efs_file_system.bi_efs.id
  subnet_id      = var.public_subnet_ids[1]
  security_groups = [aws_security_group.bi_efs.id]
}

resource "aws_efs_access_point" "bi_ap" {
  file_system_id = aws_efs_file_system.bi_efs.id
}

resource "aws_security_group" "bi_ssh" {
  name  = "bi_ssh"
  description = "Allows ssh access from an specific instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["${local.ip}/32", "10.6.0.0/16"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "bi_ssh"
  }
}

resource "aws_security_group" "bi_efs" {
  name  = "bi_efs"
  description = "Allows efs mount from anywhere in vpc"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 2049
    to_port   = 2049
    protocol  = "tcp"
    cidr_blocks = ["10.6.0.0/16"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "bi_efs"
  }
}

resource "aws_iam_role" "bi_node" {
  name = "${var.cluster_name}_bi_nodes"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = [
        "sts:AssumeRole",
        "sts:AssumeRoleWithWebIdentity"
      ]
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "bi_eks_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.bi_node.name
}

resource "aws_iam_role_policy_attachment" "bi_eks_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.bi_node.name
}

resource "aws_iam_role_policy_attachment" "bi_eks_alb" {
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.bi_node.name
}

resource "aws_iam_role_policy_attachment" "bi_eks_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.bi_node.name
}
resource "aws_iam_role_policy_attachment" "bi_eks_waf" {
  policy_arn = "arn:aws:iam::aws:policy/AWSWAFConsoleReadOnlyAccess"
  role       = aws_iam_role.bi_node.name
}

resource "aws_iam_role_policy_attachment" "bi_eks_vpc" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
  role       = aws_iam_role.bi_node.name
}

resource "aws_iam_role_policy_attachment" "bi_eks_efs" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemFullAccess"
  role       = aws_iam_role.bi_node.name
}

resource "aws_iam_role_policy_attachment" "bi_eks_autoscaling" {
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
  role       = aws_iam_role.bi_node.name
}

resource "aws_iam_instance_profile" "bi_worker_nodes" {
  name = "bi_worker_nodes"
  role = aws_iam_role.bi_node.name
}

resource "aws_launch_template" "bi_node" {
  name_prefix            = "${var.cluster_name}_bi_nodes"
  image_id               = data.aws_ssm_parameter.ami.value
  instance_type          = "t3.large"
  user_data              = base64encode(local.bi_node)
  vpc_security_group_ids = [
    aws_security_group.bi_ssh.id,
    aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
  ]
  key_name               = "k8s_key"
  iam_instance_profile {
    arn = aws_iam_instance_profile.bi_worker_nodes.arn
  }

  tags = {
    Name = "k8s_bi_nodes"
    "k8s.io/cluster-autoscaler/aws_eks_cluster.cluster.name" = "owned"
    "k8s.io/cluster-autoscaler/enabled" = "true"
    "kubernetes.io/cluster/cluster"  = "owned"
  }
}

resource "aws_autoscaling_group" "bi_node" {
  vpc_zone_identifier = concat(var.public_subnet_ids, var.private_subnet_ids)
  desired_capacity    = 1
  min_size            = 1
  max_size            = 30
  name                = "k8s_bi_nodes"
  enabled_metrics     = [
    "GroupAndWarmPoolDesiredCapacity", "GroupAndWarmPoolTotalCapacity", "GroupDesiredCapacity",
    "GroupInServiceCapacity",          "GroupInServiceInstances",       "GroupMaxSize",
    "GroupMinSize",                    "GroupPendingCapacity",          "GroupPendingInstances",
    "GroupStandbyCapacity",            "GroupStandbyInstances",         "GroupTerminatingCapacity",
    "GroupTerminatingInstances",       "GroupTotalCapacity",            "GroupTotalInstances",
    "WarmPoolDesiredCapacity",         "WarmPoolMinSize",               "WarmPoolPendingCapacity",
    "WarmPoolTerminatingCapacity",     "WarmPoolTotalCapacity",         "WarmPoolWarmedCapacity",
  ]

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 50
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.bi_node.id
        version = "$Latest"
      }

      override {
        instance_type     = "t3.large"
        weighted_capacity = "1"
      }

      override {
        instance_type     = "t3a.large"
        weighted_capacity = "1"
      }

      override {
        instance_type     = "m5.large"
        weighted_capacity = "1"
      }

      override {
        instance_type     = "c5.xlarge"
        weighted_capacity = "1"
      }
    }
  }

  tags = concat([{
    key   = "Name"
    value = "k8s_bi_nodes"
    propagate_at_launch = "true"
  }, {
    key   = "k8s.io/cluster-autoscaler/aws_eks_cluster.cluster.name"
    value ="owned"
    propagate_at_launch = "true"
  }, {
    key   = "k8s.io/cluster-autoscaler/enabled"
    value ="true"
    propagate_at_launch = "true"
  }, {
    key   = "kubernetes.io/cluster/cluster"
    value = "owned"
    propagate_at_launch = "true"
  }])

  depends_on = [
    aws_iam_role_policy_attachment.bi_eks_worker,
    aws_iam_role_policy_attachment.bi_eks_cni,
    aws_iam_role_policy_attachment.bi_eks_ecr,
    aws_iam_role_policy_attachment.bi_eks_waf,
    aws_iam_role_policy_attachment.bi_eks_alb,
    aws_iam_role_policy_attachment.bi_eks_vpc,
  ]

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
