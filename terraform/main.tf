data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "cyberchef" {
  name = "cyberchef-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.cyberchef.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "cyberchef" {
  name = "cyberchef-ssm-profile"
  role = aws_iam_role.cyberchef.name
}

resource "aws_security_group" "cyberchef" {
  name        = "cyberchef"
  description = "CyberChef security group"

  ingress {
    description = "CyberChef API"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound (apt mirrors)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS outbound (apt, Docker Hub, SSM endpoints)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# checkov:skip=CKV_AWS_126: Detailed (1-min) monitoring adds ~$2.10/mo per instance;
# not worth it for this demo t3.micro. Default 5-min basic monitoring is sufficient.
resource "aws_instance" "cyberchef" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.cyberchef.id]
  iam_instance_profile   = aws_iam_instance_profile.cyberchef.name
  ebs_optimized          = true

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
}