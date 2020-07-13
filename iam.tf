resource aws_iam_instance_profile jenkins_master {
  name = "jenkins-master"
  role = aws_iam_role.jenkins_master.name
}

resource aws_iam_role jenkins_master {
  name = "jenkins-master"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}
