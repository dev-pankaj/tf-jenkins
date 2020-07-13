#!/bin/bash

set -x

function install_packages () {
  yum update -y
  wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
  rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
  yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  yum install python2-pip jenkins java xmlstarlet nc gcc-c++ make -y
  pip install awscli bcrypt
  pip install --upgrade awscli
  pip install --upgrade aws-ec2-assign-elastic-ip
  chkconfig --add jenkins
  systemctl start jenkins
  sleep 20
}

function wait_for_jenkins()
{
  while (( 1 )); do
    echo "waiting for Jenkins to launch on port [8080] ..."

    nc -zv 127.0.0.1 8080
    if (( $? == 0 )); then
      break
    fi

    sleep 10
  done

  echo "Jenkins launched"
}

function updating_jenkins_master_password ()
{
  cat > /tmp/jenkinsHash.py <<EOF
import bcrypt
import sys
if not sys.argv[1]:
  sys.exit(10)
plaintext_pwd=sys.argv[1]
encrypted_pwd=bcrypt.hashpw(sys.argv[1], bcrypt.gensalt(rounds=10, prefix=b"2a"))
isCorrect=bcrypt.checkpw(plaintext_pwd, encrypted_pwd)
if not isCorrect:
  sys.exit(20);
print "{}".format(encrypted_pwd)
EOF

  chmod +x /tmp/jenkinsHash.py

  # Wait till /var/lib/jenkins/users/admin* folder gets created
  sleep 10

  cd /var/lib/jenkins/users/admin*
  pwd
  while (( 1 )); do
    echo "Waiting for Jenkins to generate admin user's config file ..."

    if [[ -f "./config.xml" ]]; then
      break
    fi

    sleep 10
  done

  echo "Admin config file created"

  admin_password=$(python /tmp/jenkinsHash.py ${jenkins_admin_password} 2>&1)

  # Please do not remove alter quote as it keeps the hash syntax intact or else while substitution, $<character> will be replaced by null
  xmlstarlet -q ed --inplace -u "/user/properties/hudson.security.HudsonPrivateSecurityRealm_-Details/passwordHash" -v '#jbcrypt:'"$admin_password" config.xml

  # Restart
  systemctl restart jenkins
  sleep 20
}

function configure_jenkins_server ()
{
  mkdir -p /var/lib/jenkins/.ssh
  chown -R jenkins:jenkins /var/lib/jenkins/.ssh
  echo $puplic_key > /var/lib/jenkins/.ssh/authorized_keys
  echo $puplic_key > /var/lib/jenkins/.ssh/id_rsa.pub
  echo $private_key > /var/lib/jenkins/.ssh/id_rsa
  cat > /var/lib/jenkins/.ssh/config <<EOF
Host *
  StrictHostKeyChecking no
EOF

  # Jenkins cli
  echo "installing the Jenkins cli ..."
  cp /var/cache/jenkins/war/WEB-INF/lib/cli-2.235.1.jar /var/lib/jenkins/jenkins-cli.jar

  jenkins_dir="/var/lib/jenkins"
  plugins_dir="$jenkins_dir/plugins"

  # Open JNLP port
  xmlstarlet -q ed --inplace -u "/hudson/slaveAgentPort" -v 33453 config.xml

  cd $plugins_dir || { echo "unable to chdir to [$plugins_dir]"; exit 1; }

  PASSWORD="${jenkins_admin_password}"
  # List of plugins that are needed to be installed
  plugin_list="git-client git ansible ssh-slaves"

  # remove existing plugins, if any ...
  rm -rfv $plugin_list

  for plugin in $plugin_list; do
    echo "installing plugin [$plugin] ..."
    java -jar $jenkins_dir/jenkins-cli.jar -s http://127.0.0.1:8080/ -auth admin:$PASSWORD install-plugin $plugin
  done

  JAVA_ARGS="-Djenkins.install.runSetupWizard=false"
  export JAVA_ARGS

  mkdir -p $jenkins_dir/init.groovy.d
  touch $jenkins_dir/init.groovy.d/basic-security.groovy
  cat > $jenkins_dir/init.groovy.d/basic-security.groovy <<EOF
#!groovy

import jenkins.model.*
import hudson.util.*;
import jenkins.install.*;

def instance = Jenkins.getInstance()

instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)
EOF
  # Restart jenkins after installing plugins
  java -jar $jenkins_dir/jenkins-cli.jar -s http://127.0.0.1:8080 -auth admin:$PASSWORD safe-restart

  # Give jenkins user sudo access
  echo "jenkins ALL=(ALL)NOPASSWD:ALL" >> /etc/sudoers
  sleep 10
  rm $jenkins_dir/init.groovy.d/basic-security.groovy

  # Create creds for workers
  cat > /tmp/cred.xml <<EOF
<com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey plugin="ssh-credentials@1.18.1">
  <scope>GLOBAL</scope>
  <id>ssh-worker</id>
  <description>Generated via Terraform</description>
  <username>jenkins</username>
  <privateKeySource class="com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey\$DirectEntryPrivateKeySource">
    <privateKey>$private_key</privateKey>
  </privateKeySource>
</com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey>
EOF

cat /tmp/cred.xml | java -jar $jenkins_dir/jenkins-cli.jar -s http://127.0.0.1:8080 -auth admin:$PASSWORD create-credentials-by-xml system::system::jenkins _
}

### script starts here ###

install_packages

wait_for_jenkins

updating_jenkins_master_password

wait_for_jenkins

configure_jenkins_server

echo "Done"
exit 0
