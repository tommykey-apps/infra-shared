data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

# --- Security Group ---

resource "aws_security_group" "k3s" {
  name        = "${var.project}-k3s"
  description = "Security group for K3s server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Kubernetes API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP (Traefik)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (Traefik)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
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
    Project = var.project
  }
}

# --- IAM ---

resource "aws_iam_role" "k3s" {
  name = "${var.project}-k3s"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_iam_instance_profile" "k3s" {
  name = "${var.project}-k3s"
  role = aws_iam_role.k3s.name
}

resource "aws_iam_role_policy_attachment" "k3s_ecr" {
  role       = aws_iam_role.k3s.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "k3s_ssm" {
  role       = aws_iam_role.k3s.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "k3s_ssm_put" {
  name = "${var.project}-k3s-ssm-put"
  role = aws_iam_role.k3s.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:PutParameter"
      Resource = "arn:aws:ssm:${var.region}:*:parameter/${var.project}/k3s/*"
    }]
  })
}

# --- EC2 Instance ---

resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.medium"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.k3s.id]
  iam_instance_profile   = aws_iam_instance_profile.k3s.name

  associate_public_ip_address = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/k3s-userdata.sh.tpl", {
    k3s_token = random_password.k3s_token.result
    region    = var.region
    project   = var.project
    public_ip = aws_eip.k3s.public_ip
  })

  tags = {
    Name    = "${var.project}-k3s"
    Project = var.project
  }
}

# --- Elastic IP ---

resource "aws_eip" "k3s" {
  domain = "vpc"

  tags = {
    Name    = "${var.project}-k3s"
    Project = var.project
  }
}

resource "aws_eip_association" "k3s" {
  instance_id   = aws_instance.k3s.id
  allocation_id = aws_eip.k3s.id
}

# --- SSM Parameter (placeholder, updated by user_data) ---

resource "aws_ssm_parameter" "k3s_kubeconfig" {
  name  = "/${var.project}/k3s/kubeconfig"
  type  = "SecureString"
  value = "placeholder"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Project = var.project
  }
}
