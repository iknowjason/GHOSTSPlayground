# Built with Operator lab framework (https://operatorlab.cloud)
# cmdline: python3 operator.py --ghosts -dc --windows 1 --siem elk -au 1000 --domain_join

variable "winlogbeat_zip" {
  description = "The winlogbeat zip file for windows clients x86_64"
  default     = "winlogbeat-8.9.1-windows-x86_64.zip"
}

variable "winlogbeat_config" {
  description = "The winlogbeat yml configuration file"
  default     = "winlogbeat.yml"
}

data "template_file" "winlogbeat_yml" {
  template = file("${path.module}/files/winlogbeat/${var.winlogbeat_config}.tpl")

  vars = {
    ip_address       = aws_instance.elk_server.private_ip
    elastic_username = var.elastic_username 
    elastic_password = var.elastic_password 
  }
}

resource "local_file" "winlogbeat_yml" {
  content  = data.template_file.winlogbeat_yml.rendered
  filename = "${path.module}/output/winlogbeat/${var.winlogbeat_config}"
}

resource "aws_s3_object" "winlogbeat_yml" {
  bucket = aws_s3_bucket.staging.id
  key    = var.winlogbeat_config 
  source = "${path.module}/output/winlogbeat/${var.winlogbeat_config}"
  content_type = "text/plain"

  depends_on = [
    local_file.winlogbeat_yml
  ]
}

resource "aws_s3_object" "winlogbeat_zip" {
  bucket = aws_s3_bucket.staging.id
  key    = var.winlogbeat_zip
  source = "${path.module}/files/winlogbeat/${var.winlogbeat_zip}"
  content_type = "text/plain"
}
