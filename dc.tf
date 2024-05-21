# Build the AD DS Domain Controller for Operator Lab
# Built with Operator lab framework (https://operatorlab.cloud)
# cmdline: python3 operator.py --ghosts -dc --windows 1 --siem elk -au 1000 --domain_join

variable "dc_hostname" {
  default = "dc"
}

variable "users_file" {
  default = "ad_users.csv"
}

variable "ad_install_ps1" {
  default = "ad_install.ps1"
}

# AWS AMI for Domain Controller 
data "aws_ami" "dc" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
  owners = ["801119661308"] # Amazon
}

# EC2 DC Instance
resource "aws_instance" "dc" {
  ami           = data.aws_ami.dc.id
  instance_type = "t2.small"
  key_name      = module.key_pair.key_pair_name
  subnet_id     = aws_subnet.ad_subnet.id
  private_ip     = "10.100.10.4"
  associate_public_ip_address = true

  # From windows client below 
  user_data     = data.template_file.ps_dc_template.rendered

  vpc_security_group_ids = [
    aws_security_group.operator_windows.id
  ]

  

  root_block_device {
    volume_size           = 90 
  }

  tags = {
    "Name" = "dc"
  }
  depends_on = [
  ]
}

data "template_file" "ps_dc_template" {
  template = file("${path.module}/files/dc/bootstrap-dc.ps1.tpl")

  vars  = {
    hostname                  = var.dc_hostname
    script_files              = join(",", local.script_files_win)
    s3_bucket                 = "${aws_s3_bucket.staging.id}"
    ad_domain                 = "rtc.local"
    region                    = var.region
    ad_install_script         = var.ad_install_ps1 
    admin_username            = "OpsAdmin"
    admin_password            = "Tegan-pepper-826627"
  }
}

resource "local_file" "debug_bootstrap_script" {
  # For inspecting the rendered powershell script as it is loaded onto endpoint through custom_data extension
  content = data.template_file.ps_dc_template.rendered
  filename = "${path.module}/output/dc/bootstrap-dc1.ps1"
}

resource "aws_s3_object" "ad_users_csv" {
  bucket = aws_s3_bucket.staging.id
  key    = var.users_file 
  source = "${path.module}/${var.users_file}"
  content_type = "text/plain"
}

resource "aws_s3_object" "ad_install_ps1" {
  bucket = aws_s3_bucket.staging.id
  key    = var.ad_install_ps1 
  source = "${path.module}/output/dc/${var.ad_install_ps1}"
  content_type = "text/plain"

  depends_on = [local_file.ad_install_ps1]
}

resource "local_file" "ad_install_ps1" {
  content  = data.template_file.ad_install_ps1.rendered
  filename = "${path.module}/output/dc/${var.ad_install_ps1}"
}

data "template_file" "ad_install_ps1" {
  template = file("${path.module}/files/dc/${var.ad_install_ps1}.tpl")

  vars = {
    winrm_username            = "jasonlindqvist"
    winrm_password            = "Esther-daisy-906270"
    admin_username            = "OpsAdmin"
    admin_password            = "Tegan-pepper-826627"
    ad_domain                 = "rtc.local"
    users_file                = var.users_file
    s3_bucket                 = "${aws_s3_bucket.staging.id}"
    region                    = var.region
  }
}

output "dc_ad_details" {
  value = <<EOS
-------------------------
Domain Controller and AD Details
-------------------------
Instance ID:            ${aws_instance.dc.id}
Computer Name:          ${aws_instance.dc.tags["Name"]}
Private IP:             ${aws_instance.dc.private_ip} 
Public IP:              ${aws_instance.dc.public_ip}
local Admin:            OpsAdmin 
local password:         Tegan-pepper-826627 
Domain:                 rtc.local 
Domain Admin Username:  jasonlindqvist 
Domain Admin Password:  Rue-biggie-619140 

EOS
}
