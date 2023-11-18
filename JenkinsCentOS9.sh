#!/bin/bash
#
# Auteur : guilhem Schlosser
# Date : novembre 2023
# Nom du fichier: JenkinsCenOS9.sh
# Version 1.0.0 :
# title: Self-hosted Jenkins
# Permet de:
# - Installer java-11 et ses dependances
# - Installer configurer les variables d'environnement
# - Installer Jenkins 
#
# Tester: Centos9 but maybe can work in Fedora
#
# Required: 2 core mini
#           256 MB ram
#           1 GB required but 10 GB recmmended if running Jenkins in a Docker container
#			static ip and dns configured
#			external rules firewall (pfsense (...) )
#
# To run the script: sudo bash ./JenkinsCenOS9.sh
####################################################################
# Prevent execution: test Os & Print information system
if [ -f /etc/redhat-release ] ; then
	cat /etc/redhat-release
else
	echo "Distribution is not supported"
	exit 1
fi
#####################################################################
#Variable
# Check service Jenkins running
isStarted=$(systemctl status jenkins | awk '/Active:/ {print $2}')
#Return my IP
ip_address=$(hostname -I)
#Return the host name
hostname=$(hostname)
#Return the Adminstrator password
$password="$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
#####################################################################
# PID Shell script
echo "PID of this script: $$"
#Name of script
echo "The name of the script is : $0"
#####################################################################
echo -e "\nThis script update system, install Jenkins\n\n"
sleep 1

#Update
echo -e "\nUpdate sourcelist"
yum update -y

#Install tools
echo -e "\nInstall Tools"
sudo yum -y install wget

#Install Java
echo -e "\nInstall Java"
sudo yum -y install java-11-openjdk-devel

#Creating a script to upgrade the source file with the new Java environment variables
echo -e "\nAdding Java environment variables"
cat << EOF | tee /etc/profile.d/java.sh
export JAVA_HOME=$(dirname $(dirname $(readlink $(readlink $(which javac)))))
export PATH=$PATH:$JAVA_HOME/bin
export JRE_HOME=/usr/lib/jvm/jre
export CLASSPATH=.:$JAVA_HOME/jre/lib:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
EOF

#To begin using the file without loggin out
source /etc/profile.d/java.sh

#Check
echo $JAVA_HOME

#Install RPM repository
echo -e "\nImport Jenkins key and add Jenkins repository"
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

sudo wget -O /etc/yum.repos.d/jenkins.repo http://pkg.jenkins-ci.org/redhat/jenkins.repo

#Update
echo -e "\nUpdate sourcelist"
yum update -y

#Install Jenkins
echo -e "\nInstall Jenkins"
sudo yum -y install jenkins

#Start and unable Jenkins
echo -e "\nStart Jenkins"
sudo systemctl start jenkins
sudo systemctl enable jenkins

#Chek
echo "${isStarted}"

#Opening firewall rules and restart
echo -e "Add rule 8080/tcp to the firewalld"
sudo firewall-cmd --add-port=8080/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-all | grep "8080"
firewall-cmd --reload

#How to
echo -e "\n1) Copy the following password: "${password}" to unlock Jenkins (without "")"
echo -e "\n2) Open the current ${ip_address}:8080 or http://${hostname}:8080"
