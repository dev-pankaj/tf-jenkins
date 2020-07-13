resource aws_instance jenkins_master {
  ami                    = data.aws_ami.amazon-linux-2.image_id
  instance_type          = var.instance_type
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.jenkins_master.id]
  iam_instance_profile   = aws_iam_instance_profile.jenkins_master.name
  user_data              = data.template_file.jenkins_master.rendered
  tags = {
    Name = "jenkins-master"
  }

  root_block_device {
    delete_on_termination = true
  }
}
