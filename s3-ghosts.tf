# Built with Operator lab framework (https://operatorlab.cloud)
# cmdline: python3 operator.py --ghosts -dc --windows 1 --siem elk -au 1000 --domain_join

variable "windows_count" {
  description = "The number of windows clients"
  type        = number
  default     = 1 
}

variable "ghosts_zip" {
  description = "The filename of the Windows Ghosts client zip"
  type = string
  #default = "ghosts-client-x64-v7.0.0.zip"
  default = "ghosts-client-x64-v8.0.0.zip"
}

variable "application_json" {
  description = "The filename of the application json Ghosts client config shared by all clients"
  type = string
  default = "application.json"
}

data "template_file" "bootstrap" {
  count = var.windows_count

  template = file("${path.module}/files/ghosts/ghosts-client-bootstrap.ps1.tpl")

  vars = {
    s3_bucket        = aws_s3_bucket.staging.id
    region           = var.region
    hostname         = "win${count.index + 1}"
    application_json = var.application_json
    ghosts_zip       = var.ghosts_zip
  }
}

resource "aws_s3_object" "timeline_objects" {
  count  = var.windows_count
  bucket = aws_s3_bucket.staging.id
  key    = "timeline-win${count.index + 1}.json"
  source = "files/ghosts/clients/timeline-win${count.index + 1}.json"
}

resource "aws_s3_object" "bootstrap_object" {
  count  = var.windows_count
  bucket = aws_s3_bucket.staging.id
  key    = "ghosts-bootstrap-win${count.index + 1}.ps1"
  source = local_file.bootstrap_file[count.index].filename
  depends_on = [local_file.bootstrap_file]
}

resource "local_file" "bootstrap_file" {
  count    = var.windows_count
  filename = "${path.module}/output/ghosts/client-bootstrap-${count.index + 1}.ps1"
  content  = data.template_file.bootstrap[count.index].rendered
  depends_on = [data.template_file.bootstrap]
}

data "template_file" "application_json" {
  template = file("${path.module}/files/ghosts/${var.application_json}.tpl")

  vars = {
    ghosts_server = aws_instance.ghosts_server.private_ip
  }
}

resource "local_file" "app_config" {
  content  = data.template_file.application_json.rendered
  filename = "${path.module}/output/ghosts/${var.application_json}"
}

resource "aws_s3_object" "application_json" {
  bucket = aws_s3_bucket.staging.id 
  key    = var.application_json 
  source = local_file.app_config.filename

  depends_on = [local_file.app_config]
}

resource "aws_s3_object" "ghosts_zip" {
  bucket = aws_s3_bucket.staging.id
  key    = var.ghosts_zip 
  source = "${path.module}/files/ghosts/${var.ghosts_zip}"
}
