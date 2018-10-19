# Specify the provider and access credentials
provider "aws" {
access_key = ""
secret_key = ""
region = "us-west-2"
}

resource "aws_vpc" "vpc" {
 cidr_block      = "192.168.0.0/16"
 enable_dns_support  = true
 enable_dns_hostnames = true
 tags {
  Name = "vpc-demo-us-west-terraform"
 }
}

# Create a public and private subnet in AZ 2a
resource "aws_subnet" "public_subnet_a" {
 vpc_id         = "${aws_vpc.vpc.id}"
 cidr_block       = "192.168.10.0/24"
 availability_zone    = "us-west-2a"
 map_public_ip_on_launch = false
 tags {
  Name = "subnet-2a-pub-terraform"
 }
}

resource "aws_subnet" "private_subnet_a" {
 vpc_id         = "${aws_vpc.vpc.id}"
 cidr_block       = "192.168.20.0/24"
 availability_zone    = "us-west-2a"
 tags {
  Name = "subnet-2a-priv-terraform"
 }
}

# Create a public and private subnet in AZ 2b
resource "aws_subnet" "public_subnet_b" {
 vpc_id         = "${aws_vpc.vpc.id}"
 cidr_block       = "192.168.11.0/24"
 availability_zone    = "us-west-2b"
 map_public_ip_on_launch = false
 tags {
  Name = "subnet-2b-pub-terraform"
 }
}

resource "aws_subnet" "private_subnet_b" {
 vpc_id         = "${aws_vpc.vpc.id}"
 cidr_block       = "192.168.21.0/24"
 availability_zone    = "us-west-2b"
 tags {
  Name = "subnet-2b-priv-terraform"
 }
}

# Create a public and private subnet in AZ 2c
resource "aws_subnet" "public_subnet_c" {
 vpc_id         = "${aws_vpc.vpc.id}"
 cidr_block       = "192.168.12.0/24"
 availability_zone    = "us-west-2c"
 map_public_ip_on_launch = false
 tags {
  Name = "subnet-2c-pub-terraform"
 }
}

resource "aws_subnet" "private_subnet_c" {
 vpc_id         = "${aws_vpc.vpc.id}"
 cidr_block       = "192.168.22.0/24"
 availability_zone    = "us-west-2c"
 tags {
  Name = "subnet-2c-priv-terraform"
 }
}

# Create a public internet gateway
resource "aws_internet_gateway" "internet_gateway" {
 vpc_id = "${aws_vpc.vpc.id}"
tags {
  Name = "igw-demo-pub-terraform"
 }
}

# Create a public route table
resource "aws_route_table" "public_routetable" {
  vpc_id = "${aws_vpc.vpc.id}"
 route {
  cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.internet_gateway.id}"
 }
 tags {
  Name = "rtb-demo-terraform"
 }
}

# Override the original route table that was created during VPC creation, and make the rtb-demo-terraform routable as the main route table
resource "aws_main_route_table_association" "a" {
 vpc_id     = "${aws_vpc.vpc.id}"
 route_table_id = "${aws_route_table.public_routetable.id}"
}

# Create a subnet in each AZ and associate with the main route table
resource "aws_route_table_association" "public_subnet_a" {
 subnet_id   = "${aws_subnet.public_subnet_a.id}"
 route_table_id = "${aws_route_table.public_routetable.id}"
}
resource "aws_route_table_association" "public_subnet_b" {
 subnet_id   = "${aws_subnet.public_subnet_b.id}"
 route_table_id = "${aws_route_table.public_routetable.id}"
}
resource "aws_route_table_association" "public_subnet_c" {
 subnet_id   = "${aws_subnet.public_subnet_c.id}"
 route_table_id = "${aws_route_table.public_routetable.id}"
}

# Create security groups
resource "aws_security_group" "sg-docker-nginx" {
 name    = "docker-nginx-sg-terraform"
 description = "docker-nginx-sg-terraform"
 vpc_id     = "${aws_vpc.vpc.id}"
 ingress {
  from_port  = 80
  to_port   = 80
  protocol  = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
 ingress {
  from_port  = 8080
  to_port   = 8080
  protocol  = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
 ingress {
  from_port  = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = ["10.0.0.0/16"]
 }
 egress {
 from_port = 0
 to_port = 0
 protocol = "-1"
 cidr_blocks = ["0.0.0.0/0"]
 }
 tags {
 Name = "docker-nginx-sg-terraform"
 }
}

resource "aws_security_group" "sg-postgres" {
 name    = "postgres-sg-terraform"
 description = "postgres-sg-terraform"
 vpc_id     = "${aws_vpc.vpc.id}"
 ingress {
  from_port  = 5432
  to_port   = 5432
  protocol  = "tcp"
  cidr_blocks = ["192.168.20.0/24","192.168.21.0/24","192.168.22.0/24"]
 }
 egress {
 from_port = 0
 to_port = 0
 protocol = "-1"
 cidr_blocks = ["0.0.0.0/0"]
 }
 tags {
 Name = "postgres-sg-terraform"
 }
}

resource "aws_security_group" "sg-bastion" {
 name    = "bastion-sg-terraform"
 description = "bastion-sg-terraform"
 vpc_id     = "${aws_vpc.vpc.id}"
 ingress {
  from_port  = 22
  to_port   = 22
  protocol  = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
 }
 egress {
 from_port = 0
 to_port = 0
 protocol = "-1"
 cidr_blocks = ["0.0.0.0/0"]
 }
 tags {
 Name = "bastion-sg-terraform"
 }
}

# Create an EC2 instance to serve as a bastion jump host
resource "aws_instance" "bastion-a" {
  ami     = "${var.bastion_ami_id}" #amazon-linux
  instance_type  = "t2.nano"
  availability_zone = "us-west-2a"
  subnet_id = "${aws_subnet.public_subnet_a.id}"
  security_groups = ["${aws_security_group.sg-bastion.id}"]
  tags {
   Name = "bastion-terraform"
  }
}

# Create 3 EC2 instances for high-availability - 1 per AZ
resource "aws_instance" "docker-nginx-a" {
  ami     = "${var.docker_ami_id}" #nginx-v1
  instance_type  = "t2.nano"
  availability_zone = "us-west-2a"
  subnet_id = "${aws_subnet.private_subnet_a.id}"
  security_groups = ["${aws_security_group.sg-docker-nginx.id}"]
  user_data = <<-EOF
                  #!/bin/bash
                  docker run --name docker-ngnix -p 8080:80 -v /var/nginx/html:/usr/share/nginx/html:ro -d nginx
                  EOF
  tags {
   Name = "docker-nginx-terraform"
  }
}

resource "aws_instance" "docker-nginx-b" {
  ami     = "${var.docker_ami_id}" #nginx-v1
  instance_type  = "t2.nano"
  availability_zone = "us-west-2b"
  subnet_id = "${aws_subnet.private_subnet_b.id}"
  security_groups = ["${aws_security_group.sg-docker-nginx.id}"]
  user_data = <<-EOF
                  #!/bin/bash
                  docker run --name docker-ngnix -p 8080:80 -v /var/nginx/html:/usr/share/nginx/html:ro -d nginx
                  EOF
  tags {
   Name = "docker-nginx-terraform"
  }
}

resource "aws_instance" "docker-nginx-c" {
  ami     = "${var.docker_ami_id}" #nginx-v1
  instance_type  = "t2.nano"
  availability_zone = "us-west-2c"
  subnet_id = "${aws_subnet.private_subnet_c.id}"
  security_groups = ["${aws_security_group.sg-docker-nginx.id}"]
  user_data = <<-EOF
                  #!/bin/bash
                  docker run --name docker-ngnix -p 8080:80 -v /var/nginx/html:/usr/share/nginx/html:ro -d nginx
                  EOF
  tags {
   Name = "docker-nginx-terraform"
  }
}

# Create a Ngnix ALB
resource "aws_lb" "nginx-alb-terraform" {
  name               = "nginx-alb-terraform"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.sg-docker-nginx.id}"]
  subnets            = [
  "${aws_subnet.private_subnet_a.id}",
  "${aws_subnet.private_subnet_b.id}",
  "${aws_subnet.private_subnet_c.id}"]

  enable_deletion_protection = false

  tags {
    Name = "nginx-alb-terraform"
  }
}

#Create ALB Target group
resource "aws_lb_target_group" "nginx-tg" {
  name     = "nginx-tg-terraform"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc.id}"
}

#Create ALB Target group attachments
resource "aws_lb_target_group_attachment" "nginx-tga-a" {
  target_group_arn = "${aws_lb_target_group.nginx-tg.arn}"
  target_id        = "${aws_instance.docker-nginx-a.id}"
  port             = 8080
}

resource "aws_lb_target_group_attachment" "nginx-tga-b" {
  target_group_arn = "${aws_lb_target_group.nginx-tg.arn}"
  target_id        = "${aws_instance.docker-nginx-b.id}"
  port             = 8080
}

resource "aws_lb_target_group_attachment" "nginx-tga-c" {
  target_group_arn = "${aws_lb_target_group.nginx-tg.arn}"
  target_id        = "${aws_instance.docker-nginx-c.id}"
  port             = 8080
}

# Create a DB subnet group
resource "aws_db_subnet_group" "default-tf" {
 name    = "default-terraform"
 subnet_ids = ["${aws_subnet.public_subnet_a.id}",
 "${aws_subnet.public_subnet_b.id}",
 "${aws_subnet.public_subnet_c.id}",
 "${aws_subnet.private_subnet_a.id}",
 "${aws_subnet.private_subnet_b.id}",
 "${aws_subnet.private_subnet_c.id}"]
 tags {
  Name = "My DB subnet group"
 }
}

# Create Postgres DB
resource "aws_db_instance" "postgres" {
 identifier      = "postgres-rds-terraform"
 allocated_storage  = 20
 storage_type     = "gp2"
 engine        = "postgres"
 engine_version    = "10.4"
 instance_class    = "db.t2.micro"
 name         = "postgresTerraform"
 username       = "pgadmin"
 password       = "P^ssw0rd"
 parameter_group_name = "default.postgres10"
 db_subnet_group_name = "${aws_db_subnet_group.default-tf.id}"
 final_snapshot_identifier = "rds-postgres-t2-micro-final-snapshot"
 skip_final_snapshot = true
}
