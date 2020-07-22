# Master
resource aws_security_group jenkins_master {
  name        = "jenkins-master"
  description = "Jenkins master SG, created by Terraform"

  vpc_id = data.aws_vpc.vpc.id

  tags = {
    Name = "jenkins-master"
  }
}

# ssh
resource aws_security_group_rule jenkins_master_ingress_ssh {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_master.id
  cidr_blocks       = ["0.0.0.0/0"] # block to vpc cidr
  description       = "ssh permissions for jenkins"
}

# web
resource aws_security_group_rule jenkins_master_from_source_ingress_webui {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_master.id
  cidr_blocks       = ["0.0.0.0/0"] # limit to vpn IP
  description       = "jenkins server web"
}

# JNLP
resource aws_security_group_rule jenkins_master_server_from_source_ingress_jnlp {
  type              = "ingress"
  from_port         = 33453
  to_port           = 33453
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_master.id
  cidr_blocks       = ["0.0.0.0/0"] # block to vpc cidr
  description       = "jenkins server JNLP Connection"
}

## Outbound SG
resource aws_security_group_rule jenkins_master_to_other_machines_ssh {
  type              = "egress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_master.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow jenkins master to ssh to other machines"
}

resource aws_security_group_rule jenkins_master_outbound_all_80 {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_master.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow jenkins master for outbound yum"
}

resource aws_security_group_rule jenkins_master_outbound_all_443 {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_master.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow jenkins master for outbound yum"
}

# Worker
resource aws_security_group jenkins_worker {
  name        = "jenkins-worker"
  description = "Jenkins worker SG: created by Terraform"

  vpc_id = data.aws_vpc.vpc.id

  tags = {
    Name = "jenkins-worker"
  }
}

resource aws_security_group_rule jenkins_worker_ssh {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_worker.id
  cidr_blocks       = ["0.0.0.0/0"] # block to vpc cidr
  description       = "allow ssh to worker from master"
}

resource aws_security_group_rule jenkins_worker_to_all_80 {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_worker.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow worker to all 80"
}

resource aws_security_group_rule jenkins_worker_to_all_443 {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_worker.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow worker to all 443"
}

resource aws_security_group_rule jenkins_worker_to_other_machines_ssh {
  type              = "egress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.jenkins_worker.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "allow worker to ssh master"
}

resource aws_security_group_rule jenkins_worker_to_jenkins_server_8080 {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.jenkins_worker.id
  source_security_group_id = aws_security_group.jenkins_master.id
  description              = "allow worker to access master UI"
}
