resource aws_launch_configuration jenkins_worker {
  name_prefix                 = "jenkins-worker"
  image_id                    = data.aws_ami.amazon-linux-2.image_id
  instance_type               = var.instance_type
  key_name                    = var.keypair_name
  security_groups             = [aws_security_group.jenkins_worker.id]
  user_data                   = data.template_file.jenkins_worker.rendered
  associate_public_ip_address = false

  root_block_device {
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_autoscaling_group jenkins_worker {
  name                      = "jenkins-worker"
  min_size                  = "1"
  max_size                  = "2"
  desired_capacity          = "1"
  health_check_grace_period = 60
  health_check_type         = "EC2"
  vpc_zone_identifier       = ["subnet-88697fb6"]
  launch_configuration      = aws_launch_configuration.jenkins_worker.name
  termination_policies      = ["OldestLaunchConfiguration"]
  wait_for_capacity_timeout = "10m"
  default_cooldown          = 60

  tags = [
    {
      key                 = "Name"
      value               = "jenkins-worker"
      propagate_at_launch = true
    }
  ]
}
