# Import Networking module that creates VPC and configures networking - SG etc
module "networking" {
  source    = "./modules/networking"
  namespace = var.namespace
}

# Imports modules that creates ssh key that uploads private key to aws and keeps the public key in a specified directory
module "ssh-key" {
  source    = "./modules/ssh-key"
  namespace = var.namespace
}


# Maps the environment variable to default bucket_name 

variable "environment" {
  type    = map
  default = {
    bucket_name = "Prowler_Results"
  }
}

# S3 Bucket creation

resource "aws_s3_bucket" "ProwlerScanResultsBucket" {
  bucket = "${var.ProwlerScanResults}"
  //acl    = "public-read-write"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }
}

# Setting access to S3 bucket
resource "aws_s3_bucket_public_access_block" "ProwlerScanResultsBucketPublicAccessBlock" {
  bucket                            = aws_s3_bucket.ProwlerScanResultsBucket.id
  block_public_acls                 = false
  block_public_policy               = false
  ignore_public_acls                = false
  restrict_public_buckets           = false
}

# Creation of S3 bucket policy
resource "aws_s3_bucket_policy" "ProwlerScanResultsBucketPolicy" {
  bucket = aws_s3_bucket.ProwlerScanResultsBucket.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect    = "Deny"
        Action    = ["s3:*"]
        Resource  = [aws_s3_bucket.ProwlerScanResultsBucket.arn, "${aws_s3_bucket.ProwlerScanResultsBucket.arn}/*"]
        Principal = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  })
}

# Imports the EC2 Module which creates the EC2 instance to be tested

module "ec2" {
  source     = "./modules/ec2"
  namespace  = var.namespace
  vpc        = module.networking.vpc
  sg_pub_id  = module.networking.sg_pub_id
  key_name   = module.ssh-key.key_name
  
}



// SSM Document creation
/*
resource "aws_ssm_document" "scan-process" {
  name            = "scanning"
  document_format = "YAML"
  document_type   = "Command"
  content = <<DOC
    schemaVersion: '1.2'
    description: Check ip configuration of a Linux instance.
    parameters: {}
    runtimeConfig:
      'aws:runShellScript':
        properties:
          - id: '0.aws:runShellScript'
            runCommand: 
              - echo "Enable AWS Security Hub" 
              - aws securityhub enable-security-hub --region eu-west-1
              - echo "Running prowler command to create html"
              - prowler aws -M html
              - find "/home/ec2-user/output/" -type f -name "*.html" -exec /usr/local/bin/aws s3 cp {} s3://${aws_s3_bucket.ProwlerScanResultsBucket.id}/${module.ec2.instance_id}/
              - echo "Running prowler to push to Security Hub"
              - prowler -S -f eu-west-1
              - echo " Create error log"
              - touch error.log
              - if [ $? -ne 0 ]; then  echo "Error occurred during script execution" >> error.log; fi
              - echo "S3 copy error log"
              - /usr/local/bin/aws s3 cp error.log s3://${aws_s3_bucket.ProwlerScanResultsBucket.id}/${module.ec2.instance_id}/error.log
DOC
} */

/*
resource "aws_ssm_document" "scan-process" {
  name            = "scanning"
  document_format = "YAML"
  document_type   = "Command"
  content = <<DOC
    schemaVersion: '1.2'
    description: Check ip configuration of a Linux instance.
    parameters: {}
    runtimeConfig:
      'aws:runShellScript':
        properties:
          - id: '0.aws:runShellScript'
            runCommand: 
              - prowler aws -M html
              - prowler -S -f eu-west-1
              - find "/home/ec2-user/output/" -type f -name "*.html" -exec /usr/local/bin/aws s3 cp {} s3://${aws_s3_bucket.ProwlerScanResultsBucket.id}/${module.ec2.instance_id}/ \; 

DOC
} */



/*
resource "aws_ssm_document" "scan-process" {
  name            = "scanning"
  document_format = "YAML"
  document_type   = "Command"
  content = <<DOC
    schemaVersion: '1.2'
    description: Check ip configuration of a Linux instance.
    parameters: {}
    runtimeConfig:
      'aws:runShellScript':
        properties:
          - id: '0.aws:runShellScript'
            runCommand: 
              - sudo yum install python -y
              - sudo yum install python-pip -y
              - pip install prowler
              - echo "Running prowler"
              - prowler aws -M html
              - prowler -S -f eu-west-1
              - find "/home/ec2-user/output/" -type f -name "*.html" -exec /usr/local/bin/aws s3 cp {} s3://${aws_s3_bucket.ProwlerScanResultsBucket.id}/${module.ec2.instance_id}/ \;
DOC
} */



// SSM Document is invoked

/*resource "aws_ssm_association" "run_ssm" {
  name = aws_ssm_document.scan-process.name

  targets {
    key    = "InstanceIds"
    values = ["${module.ec2.instance_id}"]
  }
}*/