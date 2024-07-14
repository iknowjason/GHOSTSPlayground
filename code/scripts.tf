## Terraform for scripts to bootstrap
# Built with Operator lab framework (https://operatorlab.cloud)
# cmdline: python3 operator.py --ghosts -dc --windows 1 --siem elk -au 1000 --domain_join

locals {

  # Windows systems 
  templatefiles_win = [
    
    {
      name = "${path.module}/files/windows/red.ps1.tpl"
      variables = {
        s3_bucket = "${aws_s3_bucket.staging.id}"
      }
    },
    
        {
      name = "${path.module}/files/windows/sysmon.ps1.tpl"
      variables = {
        s3_bucket     = "${aws_s3_bucket.staging.id}"
        region        = var.region
        sysmon_config = local.sysmon_config
        sysmon_zip    = local.sysmon_zip
        dc_ip         = "" 
        domain_join   = true 
      }
    },
    
    
    
    
        {
      name = "${path.module}/files/windows/winlogbeat.ps1.tpl"
      variables = {
        s3_bucket     = "${aws_s3_bucket.staging.id}"
        region        = var.region
        winlogbeat_config = var.winlogbeat_config
        winlogbeat_zip    = var.winlogbeat_zip
        ip_address        = aws_instance.elk_server.private_ip
      }
    },
    
  ]

  script_contents_win = [
    for t in local.templatefiles_win : templatefile(t.name, t.variables)
  ]

  script_output_generated_win = [
    for t in local.templatefiles_win : "${path.module}/output/windows/${replace(basename(t.name), ".tpl", "")}"
  ]

  # reference in the main user_data for each windows system
  script_files_win = [
    for tf in local.templatefiles_win :
    replace(basename(tf.name), ".tpl", "")
  ]
}

resource "local_file" "generated_scripts_win" {
  count = length(local.templatefiles_win)
  filename = local.script_output_generated_win[count.index]
  content  = local.script_contents_win[count.index]
}
