terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region                  = "us-east-1"
  shared_credentials_file = "/Users/manikjain/.aws/creds"
}

resource "aws_vpc" "dev" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "dev"
  }
} 

resource "aws_subnet" "dev_private" {
  vpc_id     = aws_vpc.dev.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "dev_private"
  }
}

resource "aws_subnet" "dev_public1" {
  vpc_id            = aws_vpc.dev.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "dev_public1"
  }
}

resource "aws_subnet" "dev_public2" {
  vpc_id            = aws_vpc.dev.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "dev_public2"
  }
}

resource "aws_eip" "dev_gw_NAT" {
  vpc = true
  tags = {
    Name = "dev_gw_NAT"
  }
}

resource "aws_nat_gateway" "dev_gw_NAT" {
  allocation_id = aws_eip.dev_gw_NAT.id
  subnet_id     = aws_subnet.dev_public1.id

  tags = {
    Name = "dev"
  }

  depends_on = [aws_internet_gateway.dev_gw_internet]
}

resource "aws_internet_gateway" "dev_gw_internet" {
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = "dev"
  }
}

resource "aws_route_table" "dev_public_route_table" {
  vpc_id = aws_vpc.dev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_gw_internet.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.dev_gw_internet.id
  }

  tags = {
    Name = "dev"
  }
}

resource "aws_route_table_association" "dev_public1" {
  subnet_id      = aws_subnet.dev_public1.id
  route_table_id = aws_route_table.dev_public_route_table.id
}

resource "aws_route_table_association" "dev_public2" {
  subnet_id      = aws_subnet.dev_public2.id
  route_table_id = aws_route_table.dev_public_route_table.id
}

resource "aws_security_group" "dev_allow_web" {
  name        = "dev_allow_web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.dev.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "dev_public1" {
  subnet_id       = aws_subnet.dev_public1.id
  private_ips     = ["10.0.2.50"]
  security_groups = [aws_security_group.dev_allow_web.id]

  # attachment {
  #   instance     = aws_instance.test.id
  #   device_index = 1
  # }
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.dev_public1.id
  associate_with_private_ip = "10.0.2.50"

  depends_on = [aws_internet_gateway.dev_gw_internet]
}

resource "aws_instance" "dev_web" {
  ami               = "ami-0dba2cb6798deb6d8"
  instance_type     = "t3.micro"
  availability_zone = "us-east-1a"
  key_name          = "dev"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.dev_public1.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo "Web Server - $(hostname)" > /var/www/html/index.html'
                EOF

  tags = {
    Name = "dev_web"
  }
}

resource "aws_security_group" "dev_elb" {
  name   = "dev_elb"
  vpc_id = aws_vpc.dev.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "dev_web" {
  name     = "dev-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.dev.id
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.dev_web.arn
  target_id        = aws_instance.dev_web.id
  port             = 80
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.dev_elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dev_web.arn
  }
}

resource "aws_lb" "dev_elb" {
  name               = "dev-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.dev_elb.id]
  subnets            = [aws_subnet.dev_public1.id, aws_subnet.dev_public2.id]

  tags = {
    Name = "dev_lb"
  }
}

data "aws_ami" "dev_web" {

  filter {
    name   = "name"
    values = ["dev_web"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["394894109721"] # Canonical
}

resource "aws_launch_configuration" "dev_web" {
  name_prefix   = "dev_web-"
  image_id      = data.aws_ami.dev_web.id
  instance_type = "t3.micro"
  associate_public_ip_address = true
  security_groups = [aws_security_group.dev_allow_web.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "dev_web" {
  name                 = "dev_web"
  launch_configuration = aws_launch_configuration.dev_web.name
  vpc_zone_identifier  = [aws_subnet.dev_public1.id]
  min_size             = 1
  max_size             = 3

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_attachment" "dev_web" {
  autoscaling_group_name = aws_autoscaling_group.dev_web.id
  alb_target_group_arn   = aws_lb_target_group.dev_web.arn
}

resource "aws_autoscaling_policy" "dev_web_scale_up" {
  name                   = "dev-web-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.dev_web.name
}

resource "aws_cloudwatch_metric_alarm" "dev_web_scale_up" {
  alarm_name          = "dev_web_cpu_usage_exceeded"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.dev_web.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.dev_web_scale_up.arn]
}

resource "aws_autoscaling_policy" "dev_web_scale_down" {
  name                   = "dev-web-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.dev_web.name
}

resource "aws_cloudwatch_metric_alarm" "dev_web_scale_down" {
  alarm_name          = "dev_web_cpu_usage_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "60"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.dev_web.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.dev_web_scale_down.arn]
}
