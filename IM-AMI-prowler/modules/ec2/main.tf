// Data filter searches for AMI 

data "aws_ami" "rhel9" {
  most_recent = true

  filter {
    name   = "image-id"
    values = ["ami-0d4c8980f82214765"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
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
    name   = "name"
    values = ["composer-api-59660118-01ae-4f13-9e9a-d8f8b0629ff1"]
  }
}

/*
data "template_file" "cw" {
  template = file("${path.module}/cw.sh")
} 
*/




// IAM role that gives access to SSM + S3 via EC2 instance 

resource "aws_cloudwatch_log_group" "ec2_logs" {
  name = "/ec2-instance-logs"
}

resource "aws_cloudwatch_log_stream" "ec2_log_stream" {
  name           = "my-ec2-log-stream"
  log_group_name = aws_cloudwatch_log_group.ec2_logs.name
}


resource "aws_iam_role" "CW-SH-S3-SSM-IamRole" {
  name = "cw-sh-s3-ssm-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

// S3 Policy creation 

resource "aws_iam_policy" "policy-for-s3" {
  name        = "policy-for-s3"
  description = "Policy for S3"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
EOF
}

// iam policy for ssm 

resource "aws_iam_policy" "policy-for-ssm" {
  name = "ssm-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ssm:*",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "policy-for-sh" {
  name = "sh-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "securityhub:*",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "policy-for-cw" {
  name        = "cw-policy"
  description = "IAM policy for CloudWatch access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "cloudwatch:*",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_cloudwatch_logs_policy" {
  name        = "EC2CloudWatchLogsPolicy"
  description = "Allows EC2 instances to send logs to CloudWatch"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = [
          aws_cloudwatch_log_group.ec2_logs.arn,
          aws_cloudwatch_log_stream.ec2_log_stream.arn
        ]
      }
    ]
  })
}




// Policy attachment for ssm and s3 policy to role

resource "aws_iam_role_policy_attachment" "cw-sh-s3-ssm-attach" {
  for_each = {
    "policy-for-s3"   = aws_iam_policy.policy-for-s3.arn
    "policy-for-ssm"  = aws_iam_policy.policy-for-ssm.arn
    "policy-for-sh"  = aws_iam_policy.policy-for-sh.arn
    //"policy-for-cw" = aws_iam_policy.policy-for-cw.arn
    //"policy-for-logs" = aws_iam_policy.ec2_cloudwatch_logs_policy.arn
    //"s3-full-access"  = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    //"ssm-full-access" = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
    "cloudwatch-full-access" = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
    //"securityhub-full-access" = "arn:aws:iam::aws:policy/SecurityHubFullAccess"
  }

  role       = aws_iam_role.CW-SH-S3-SSM-IamRole.name
  policy_arn = each.value
}

// Adding role to instance profile

resource "aws_iam_instance_profile" "instance_profile" {
  name = "CW-SH-S3-SSM-IamProfile"
  role = aws_iam_role.CW-SH-S3-SSM-IamRole.name
}



//Creation of EC2 instance

resource "aws_instance" "ec2_public" {
  count                       = 2
  ami                         = data.aws_ami.rhel9.id
  //user_data     = templatefile("${path.module}/cw.tfpl",{})
  associate_public_ip_address = true
  instance_type               = "t3.2xlarge"
  key_name                    = var.key_name
  subnet_id                   = var.vpc.public_subnets[0]
  vpc_security_group_ids      = [var.sg_pub_id]
  iam_instance_profile        = "CW-SH-S3-SSM-IamProfile"
  tags = {
    "Name" = "${var.namespace}"
  }

  provisioner "file" {
    source      = "./${var.key_name}.pem"
    destination = "/home/ec2-user/${var.key_name}.pem"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  } 
  
 provisioner "remote-exec" {
    inline = [
      "chmod 400 ~/${var.key_name}.pem"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }
   provisioner "file" {
    source      = "${path.module}/cw.sh"
    destination = "/home/ec2-user/cw.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
      
    }
  }

  //Configuration of EC2 instance
  provisioner "remote-exec" {
    inline = [ 
      "/bin/bash /home/ec2-user/cw.sh"

    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  } 



 






// Configuration of EC2 instance
 /* provisioner "remote-exec" {
    inline = [ 
      "sudo subscription-manager remove --all",   
      "sudo subscription-manager clean",
      "sudo subscription-manager register --username rh-ee-oezeakac  --password Ambrosius925! --auto-attach",
      "sudo yum install unzip -y",
      "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
      "unzip awscliv2.zip",
      "sudo ./aws/install",
      "sudo yum install -y https://s3.eu-west-1.amazonaws.com/amazon-ssm-eu-west-1/latest/linux_amd64/amazon-ssm-agent.rpm",
      "sudo systemctl enable amazon-ssm-agent",
      "sudo systemctl start amazon-ssm-agent"

    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  } */
}

