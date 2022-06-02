terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    null = {
      source = "hashicorp/null"
    }
    random = {
      source = "hashicorp/random"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
    }
  }
}

provider "aws" {
  allowed_account_ids = [var.account_id]
  region              = var.region
}

data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = "true"

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.0.0.0/19"
}

resource "aws_default_route_table" "rt" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh" {
  key_name   = "ssh_${var.cluster_name}"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_security_group" "zeet" {
  name        = var.cluster_name
  description = "zeet"
  vpc_id      = aws_vpc.vpc.id

  # ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # k3s api
  ingress {
    from_port   = 2337
    to_port     = 2337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # http
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # https
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # output
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # self
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
}

resource "random_password" "secret" {
  length = 32
}

data "cloudinit_config" "init" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/init.sh",
      {
        k3s_version   = var.k3s_version,
        cluster_token = random_password.secret.result,
        cluster_dns   = var.cluster_dns,
    })
  }
}

resource "aws_instance" "zeet" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.ssh.key_name

  subnet_id                   = aws_subnet.subnet.id
  availability_zone           = data.aws_availability_zones.available.names[0]
  vpc_security_group_ids      = [aws_security_group.zeet.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.zeet.name

  root_block_device {
    volume_size = 20
  }

  user_data = data.cloudinit_config.init.rendered

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_ebs_volume" "ebs" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 10

  tags = {
    Name = var.cluster_name
  }
}

resource "aws_volume_attachment" "ebs_attch" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.ebs.id
  instance_id = aws_instance.zeet.id
}

data "aws_route53_zone" "zeet" {
  name = var.cluster_dns
}

resource "aws_route53_record" "zeet" {
  zone_id = data.aws_route53_zone.zeet.zone_id
  name    = var.cluster_dns
  type    = "A"
  ttl     = "300"
  records = [aws_instance.zeet.public_ip]
}

resource "aws_route53_record" "zeet-wildcard" {
  zone_id = data.aws_route53_zone.zeet.zone_id
  name    = "*.${var.cluster_dns}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.zeet.public_ip]
}
