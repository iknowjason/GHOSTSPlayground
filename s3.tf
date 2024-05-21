## S3 bucket and objects
# Built with Operator lab framework (https://operatorlab.cloud)
# cmdline: python3 operator.py --ghosts -dc --windows 1 --siem elk -au 1000 --domain_join

resource "aws_s3_bucket" "staging" {
  bucket = "operator-staging-${local.rs}"

  tags = {
    Name        = "Operator Lab"
    Environment = "Dev"
  }
}


data "aws_iam_policy_document" "public_access" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.staging.arn}/*"]
    effect    = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "staging" {
  bucket = aws_s3_bucket.staging.id
  policy = data.aws_iam_policy_document.public_access.json
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket = aws_s3_bucket.staging.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "template_objects" {
  count  = length(local.templatefiles_win)
  bucket = aws_s3_bucket.staging.id
  key    = "${replace(basename(local.templatefiles_win[count.index].name), ".tpl", "")}"
  content = local.script_contents_win[count.index]
}
    
output "storage_bucket" {
  value   = aws_s3_bucket.staging.id
}
