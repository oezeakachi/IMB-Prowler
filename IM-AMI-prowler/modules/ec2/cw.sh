#!/bin/bash

# Install Cloudwatch agent 



package="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"

zip="awscliv2.zip"

touch subscription-manager-remove--all.txt

sudo subscription-manager remove --all  

touch subscription-manager-clean.txt

sudo subscription-manager clean

touch subscription-manager register-command.txt

sudo subscription-manager register --username rh-<id>  --password <password> --auto-attach

touch unzip-install.txt

sudo yum install python-pip -y

pip install prowler-cloud

sudo yum install unzip -y

touch curl-https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip-o-awscliv2.zip.txt

curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'

touch unzip-awscliv2.zip.txt

sudo unzip awscliv2.zip

touch ./aws/install.txt 

sudo ./aws/install

touch yum-install-y-https://s3.eu-west-1.amazonaws.com/amazon-ssm-eu-west-1/latest/linux_amd64/amazon-ssm-agent.rpm.txt

sudo yum install -y https://s3.eu-west-1.amazonaws.com/amazon-ssm-eu-west-1/latest/linux_amd64/amazon-ssm-agent.rpm


touch enable-amazon-ssm-agent.rpm.txt

sudo systemctl enable amazon-ssm-agent

touch start-amazon-ssm-agent.rpm.txt

sudo systemctl start amazon-ssm-agent

touch install-wget.txt

sudo yum install wget -y

touch cloudwatch-agent-download-flag.txt

sudo wget https://s3.amazonaws.com/amazoncloudwatch-agent/redhat/amd64/latest/amazon-cloudwatch-agent.rpm

touch cloudwatch-agent-install.txt

sudo rpm -U ./amazon-cloudwatch-agent.rpm

# Write Cloudwatch agent configuration file

sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d

sudo touch /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/amazon-cloudwatch-agent.json

sudo cat >> /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/amazon-cloudwatch-agent.json <<EOF
{
  "agent": {
    "run_as_user": "ec2-user"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "ec2-instance-logs",
            "log_stream_name": "my-ec2-log-stream"
          }
        ]
      }
    }
  }
}
EOF

touch startcloudwatch-install.txt
# Start Cloudwatch agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/amazon-cloudwatch-agent.json


prowler aws -M html

prowler -S -f eu-west-1

sudo find "/home/ec2-user/output/" -type f -name "*.html" -exec /usr/local/bin/aws s3 cp {} s3://prowler-scan-bucket/scans/ \; 



  