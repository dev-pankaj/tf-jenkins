#!/bin/bash

set -x

function install_packages ()
{
  yum update -y
  amazon-linux-extras install ansible2 -y
  yum install git java nc -y
}

function wait_for_jenkins ()
{
  echo "Waiting jenkins server to launch on 8080..."

  while (( 1 )); do
    echo "Waiting for Jenkins server"

    nc -zv ${server_ip} 8080
    if (( $? == 0 )); then
        break
    fi

    sleep 10
  done

  echo "Jenkins server launched"
}

function worker_setup()
{
  # Wait till jar file gets available
  ret=1
  while (( $ret != 0 )); do
    wget -O /opt/jenkins-cli.jar http://${server_ip}:8080/jnlpJars/jenkins-cli.jar
    ret=$?

    echo "jenkins cli ret [$ret]"
  done

  ret=1
  while (( $ret != 0 )); do
    wget -O /opt/slave.jar http://${server_ip}:8080/jnlpJars/slave.jar
    ret=$?

    echo "jenkins worker ret [$ret]"
  done

  useradd -d /var/lib/jenkins jenkins
  echo "jenkins ALL=(ALL)NOPASSWD:ALL" >> /etc/sudoers
  mkdir /var/lib/jenkins/.ssh
  chown -R jenkins:jenkins /home/jenkins/.ssh
  echo $puplic_key > /var/lib/jenkins/.ssh/authorized_keys
  echo $puplic_key > /var/lib/jenkins/.ssh/id_rsa.pub
  echo $private_key > /var/lib/jenkins/.ssh/id_rsa
  cat > /var/lib/jenkins/.ssh/config <<EOF
Host *
  StrictHostKeyChecking no
EOF

  JENKINS_URL="http://${server_ip}:8080"
  USERNAME="${jenkins_username}"
  PASSWORD="${jenkins_password}"
  WORKER_IP=$(ip -o -4 addr list ${device_name} | head -n1 | awk '{print $4}' | cut -d/ -f1)
  NODE_NAME=$(echo "jenkins-worker-$WORKER_IP" | tr '.' '-')
  NODE_WORKER_HOME="/var/lib/jenkins"
  EXECUTORS=2
  SSH_PORT=22
  CRED_ID="ssh-worker"
  LABELS="worker-build"
  USERID="jenkins"

  cd /opt

  # Creating CMD utility for jenkins-cli commands
  jenkins_cmd="java -jar /opt/jenkins-cli.jar -s $JENKINS_URL -auth $USERNAME:$PASSWORD"

  # Waiting for Jenkins to load all plugins
  while (( 1 )); do
    count=$($jenkins_cmd list-plugins 2>/dev/null | wc -l)
    ret=$?

    echo "count [$count] ret [$ret]"

    if (( $count > 0 )); then
        break
    fi

    sleep 30
  done

  # Generating node.xml for creating node on Jenkins server
  cat > /tmp/node.xml <<EOF
<?xml version="1.1" encoding="UTF-8"?>
<slave>
  <name>$NODE_NAME</name>
  <description>Linux worker</description>
  <remoteFS>$NODE_WORKER_HOME</remoteFS>
  <numExecutors>$EXECUTORS</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy\$Always"/>
  <launcher class="hudson.plugins.sshslaves.SSHLauncher" plugin="ssh-slaves@1.31.2">
    <host>$WORKER_IP</host>
    <port>$SSH_PORT</port>
    <credentialsId>$CRED_ID</credentialsId>
    <sshHostKeyVerificationStrategy class="hudson.plugins.sshslaves.verifiers.NonVerifyingKeyVerificationStrategy"/>
  </launcher>
  <label>$LABELS</label>
  <nodeProperties/>
</slave>
EOF

  sleep 10

  # Creating node using node.xml
  cat /tmp/node.xml | $jenkins_cmd create-node $NODE_NAME
}

### script begins here ###
install_packages

wait_for_jenkins

worker_setup

echo "Done"
exit 0
