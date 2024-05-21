# Built with Operator lab framework (https://operatorlab.cloud)
# cmdline: python3 operator.py --ghosts -dc --windows 1 --siem elk -au 1000 --domain_join

variable "ghosts_server_instance_type" {
  description = "The AWS instance type to use for servers."
  default     = "t3a.medium"
}

variable "ghosts_root_block_device_size" {
  description = "The volume size of the root block device."
  default     =  96 
}

resource "aws_security_group" "ghosts_ingress" {
  name   = "ghosts-ingress"
  vpc_id = aws_vpc.operator.id

  # Ghosts api 
  ingress {
    from_port       = 5000 
    to_port         = 5000 
    protocol        = "tcp"
    cidr_blocks     = [local.src_ip]
  }

  # Ghosts Grafana 
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    cidr_blocks     = [local.src_ip]
  }

  # Ghosts Animator 
  ingress {
    from_port       = 5001
    to_port         = 5001
    protocol        = "tcp"
    cidr_blocks     = [local.src_ip]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ghosts_ssh_ingress" {
  name   = "ghosts-ssh-ingress"
  vpc_id = aws_vpc.operator.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.src_ip]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ghosts_allow_all_internal" {
  name   = "ghosts-allow-all-internal"
  vpc_id = aws_vpc.operator.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }
}

data "aws_ami" "ghosts_server" {
  most_recent      = true
  owners           = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "ghosts_server" {
  ami                    = data.aws_ami.ghosts_server.id
  instance_type          = var.ghosts_server_instance_type
  subnet_id              = aws_subnet.user_subnet.id
  key_name               = module.key_pair.key_pair_name 
  vpc_security_group_ids = [aws_security_group.ghosts_ingress.id, aws_security_group.ghosts_ssh_ingress.id, aws_security_group.ghosts_allow_all_internal.id]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.private_key.private_key_pem
    host        = self.public_ip
  }

  tags = {
    "Name" = "ghosts"
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.ghosts_root_block_device_size
    delete_on_termination = "true"
  }

  user_data = templatefile("files/ghosts/bootstrap.sh.tpl", {
    s3_bucket                 = "${aws_s3_bucket.staging.id}" 
    region                    = var.region
  })

}

output "Ghosts_server_details" {
  value = <<CONFIGURATION
----------------
GHOSTS Grafana Console:
----------------
http://${aws_instance.ghosts_server.public_dns}:3000

GHOSTS Grafana Credentials:
--------------------
admin:admin

GHOSTS API Server
-----------------
http://${aws_instance.ghosts_server.public_dns}:5000

SSH to GHOSTS
--------------
ssh -i ssh_key.pem ubuntu@${aws_instance.ghosts_server.public_ip}  


CONFIGURATION
}

resource "aws_s3_object" "ghosts_docker_compose" {
  bucket = aws_s3_bucket.staging.id
  key    = "docker-compose.yml"
  source = "${path.module}/files/ghosts/docker-compose.yml"
  content_type = "text/plain"
}

resource "aws_s3_object" "ghosts_datasources_yml" {
  bucket = aws_s3_bucket.staging.id
  key    = "datasources.yml"
  source = local_file.ghosts_datasources_yml.filename 
  content_type = "text/plain"

  depends_on = [local_file.ghosts_datasources_yml]
}

data "template_file" "ghosts_datasources" {
  template = file("${path.module}/files/ghosts/datasources.yml.tpl")

  vars = {
    ghosts_server = aws_instance.ghosts_server.private_ip 
  }
}

resource "local_file" "ghosts_datasources_yml" {
  content  = data.template_file.ghosts_datasources.rendered
  filename = "${path.module}/output/ghosts/datasources.yml"
}

resource "aws_s3_object" "ghosts_dashboards_yml" {
  bucket = aws_s3_bucket.staging.id
  key    = "dashboards.yml"
  source = "${path.module}/files/ghosts/dashboards.yml"
  content_type = "text/plain"

}

resource "aws_s3_object" "ghosts_default_grafana_dashboard_yml" {
  bucket = aws_s3_bucket.staging.id
  key    = "GHOSTS-5-default-Grafana-dashboard.json"
  source = "${path.module}/files/ghosts/GHOSTS-5-default-Grafana-dashboard.json"
  content_type = "text/plain"
}

resource "aws_s3_object" "ghosts_group_default_grafana_dashboard_yml" {
  bucket = aws_s3_bucket.staging.id
  key    = "GHOSTS-5-group-default-Grafana-dashboard.json"
  source = "${path.module}/files/ghosts/GHOSTS-5-group-default-Grafana-dashboard.json"
  content_type = "text/plain"
}

resource "aws_s3_object" "animator_appsettings_json" {
  bucket = aws_s3_bucket.staging.id
  key    = "appsettings.json"
  source = "${path.module}/files/ghosts/appsettings.json"
  content_type = "text/plain"
}
