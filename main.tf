provider "aws" {
  region = "us-east-2"
}

variable "server_port" {
  description = "Port number of the application"
  type        = number
  default     = 8080
}

resource "aws_security_group" "instance" {
  name = "terraform-example-CIRD"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "example" {
  image_id      = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF
  )

  # Indispensable quand l'ASG référence ce template : on crée le nouveau
  # avant de détruire l'ancien.
  lifecycle {
    create_before_destroy = true
  }
}

# VPC par défaut et ses subnets, pour déployer l'ASG sans les coder en dur.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_autoscaling_group" "example" {
  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }

  vpc_zone_identifier = data.aws_subnets.default.ids

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

output "server_port" {
  description = "CIRD port number applied"
  value       = var.server_port
}
