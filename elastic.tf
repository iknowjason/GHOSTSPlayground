# The terraform file that creates the Elastic Stack server system
# Built with Operator lab framework (https://operatorlab.cloud)
# cmdline: python3 operator.py --ghosts -dc --windows 1 --siem elk -au 1000 --domain_join

variable "elastic_username" {
  description = "The elastic username for bootstrap and logging into kibana initially"
  default     = "elastic"
}
variable "hostname" {
  description = "The fqdn or hostname for setting ssl CN and hostname command"
  default     = "elastic.operatorlab.cloud"
}
variable "elastic_password" {
  description = "The bootstrap password for elastic user and kibana_system"
  default     = "Elastic2024"
}
variable "elk_server_instance_type" {
  description = "The AWS instance type to use for servers."
  default     = "t2.xlarge"
}

variable "elk_root_block_device_size" {
  description = "The volume size of the root block device."
  default     =  100 
}

resource "aws_security_group" "elk_ingress" {
  name   = "elk-ingress"
  vpc_id = aws_vpc.operator.id

  # Server port Kibana 
  ingress {
    from_port       = 5601 
    to_port         = 5601 
    protocol        = "tcp"
    cidr_blocks     = [local.src_ip]
  }

  # Server port ssh
  ingress {
    from_port       = 22 
    to_port         = 22 
    protocol        = "tcp"
    cidr_blocks     = [local.src_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "elk_ssh_ingress" {
  name   = "elk-ssh-ingress"
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

resource "aws_security_group" "elk_allow_all_internal" {
  name   = "elk-allow-all-internal"
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

data "aws_ami" "elk_server" {
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

resource "aws_instance" "elk_server" {
  ami                    = data.aws_ami.elk_server.id
  instance_type          = var.elk_server_instance_type
  subnet_id              = aws_subnet.user_subnet.id
  key_name               = module.key_pair.key_pair_name 
  vpc_security_group_ids = [aws_security_group.elk_ingress.id, aws_security_group.elk_ssh_ingress.id, aws_security_group.elk_allow_all_internal.id]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.private_key.private_key_pem
    host        = self.public_ip
  }

  tags = {
    "Name" = "elk"
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.elk_root_block_device_size
    delete_on_termination = "true"
  }

  user_data = templatefile("files/elastic/bootstrap.sh.tpl", {
    s3_bucket                 = "${aws_s3_bucket.staging.id}" 
    region                    = var.region
    elastic_username          = var.elastic_username
    elastic_password          = var.elastic_password
    hostname                  = var.hostname
  })

}

data "template_file" "kibana_yml" {
  template = file("${path.module}/files/elastic/kibana.yml.tpl")

  vars = {
    ip_address = aws_instance.elk_server.private_ip
    elastic_password = var.elastic_password 
  }
}

data "template_file" "logstash_conf" {
  template = file("${path.module}/files/elastic/logstash.conf.tpl")

  vars = {
    elastic_username = var.elastic_username
    elastic_password = var.elastic_password
  }
}

data "template_file" "elasticsearch_yml" {
  template = file("${path.module}/files/elastic/elasticsearch.yml.tpl")

  vars = {
    ip_address = aws_instance.elk_server.private_ip
  }
}

resource "local_file" "kibana_yml" {
  content  = data.template_file.kibana_yml.rendered
  filename = "${path.module}/output/elastic/kibana.yml"
}

resource "local_file" "logstash_conf" {
  content  = data.template_file.logstash_conf.rendered
  filename = "${path.module}/output/elastic/logstash.conf"
}

resource "local_file" "elasticsearch_yml" {
  content  = data.template_file.elasticsearch_yml.rendered
  filename = "${path.module}/output/elastic/elasticsearch.yml"
}

resource "aws_s3_object" "kibana_yml" {
  bucket = aws_s3_bucket.staging.id
  key    = "kibana.yml"
  source = "${path.module}/output/elastic/kibana.yml"
  content_type = "text/plain"

  depends_on = [
    local_file.kibana_yml
  ]
}

resource "aws_s3_object" "logstash_conf" {
  bucket = aws_s3_bucket.staging.id
  key    = "logstash.conf"
  source = "${path.module}/output/elastic/logstash.conf"
  content_type = "text/plain"

  depends_on = [
    local_file.logstash_conf
  ]
}

resource "aws_s3_object" "elasticsearch_yml" {
  bucket = aws_s3_bucket.staging.id
  key    = "elasticsearch.yml"
  source = "${path.module}/output/elastic/elasticsearch.yml"
  content_type = "text/plain"

  depends_on = [
    local_file.elasticsearch_yml
  ]

}

resource "aws_s3_object" "elastic_service_config" {
  bucket = aws_s3_bucket.staging.id
  key    = "elasticsearch.service"
  source = "${path.module}/files/elastic/elasticsearch.service"
  content_type = "text/plain"
}

resource "aws_s3_object" "logstash_service_config" {
  bucket = aws_s3_bucket.staging.id
  key    = "logstash.service"
  source = "${path.module}/files/elastic/logstash.service"
  content_type = "text/plain"
}

resource "aws_s3_object" "kibana_service_config" {
  bucket = aws_s3_bucket.staging.id
  key    = "kibana.service"
  source = "${path.module}/files/elastic/kibana.service"
  content_type = "text/plain"
}

output "Elastic_server_details" {
  value = <<CONFIGURATION
-------
Kibana Console
-------
https://${aws_instance.elk_server.public_dns}:5601
username: ${var.elastic_username}
password: ${var.elastic_password}

SSH to Kibana
-------------
ssh -i ssh_key.pem ubuntu@${aws_instance.elk_server.public_ip}  

CONFIGURATION
}
