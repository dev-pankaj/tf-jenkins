data aws_ami amazon-linux-2 {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data aws_ssm_parameter jenkins_admin_password {
  name = "/demo/jenkins/JENKINS_ADMIN_PASSWORD"
}

data aws_ssm_parameter jenkins_private_key {
  name = "/demo/jenkins/PRIVATE_KEY"
}

data aws_ssm_parameter jenkins_public_key {
  name = "/demo/jenkins/PUBLIC_KEY"
}

data template_file jenkins_master {
  template = file("scripts/master.sh")

  vars = {
    jenkins_admin_password = data.aws_ssm_parameter.jenkins_admin_password.value
    puplic_key = data.aws_ssm_parameter.jenkins_public_key.value
    private_key = data.aws_ssm_parameter.jenkins_private_key.value
  }
}

data template_file jenkins_worker {
  template = file("scripts/worker.sh")

  vars = {
    device_name      = "eth0"
    server_ip        = aws_instance.jenkins_master.private_ip
    jenkins_username = "admin"
    jenkins_password = data.aws_ssm_parameter.jenkins_admin_password.value
    puplic_key = data.aws_ssm_parameter.jenkins_public_key.value
    private_key = data.aws_ssm_parameter.jenkins_private_key.value
  }
}
