#!/bin/bash
#
# Auteur : guilhem Schlosser
# Date : Aout 2022
# Nom du fichier: auto_gitlab_postfix_install.sh
# Version 1.0.0 :
# title: Self-hosted gitlab-ee
# Permet de:
# - Installer les mises à jour système
# - Installer postfix (non paramétré)
# - Installer gitlab
# - Ajoute les règles de firewall nécessaire (firewalld uniquement)
#
# Tester: Centos9
#
# Required: 2 core mini
#           2048 mo ram mini
#			static ip and dns configured
#			external rules firewall (pfsense (...) )
#
# To run the script: sudo bash ./auto_gitlab_postfix_install.sh
####################################################################
# PID Shell script
echo "PID of this script: $$"
#Name of script
echo "The name of the script is : $0"
#####################################################################
# Prevent execution: test Os & Print information system
if [ -f /etc/redhat-release ] ; then
	cat /etc/redhat-release
else
	echo "Distribution is not supported"
	exit 1
fi
#####################################################################

# Cleaning old entry
yum clean all -y

#Install GPG key elrepo
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org

#Install the ELRepo Repository
rpm -Uvh https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm

#Update sourcelist
yum update -y

#Enabling the EPL repository
yum install epel-release -y

#Install curl policy security and openssh-server and perl"
## Liste des paquets à installer
packages=("curl" "policycoreutils-python.x86_64" "openssh-server" "perl")

# Check si les paquets sont installés
for package in "${packages[@]}"; do
    if ! rpm -q "$package" > /dev/null 2>&1; then
        # Installe le paquet s'il n'est pas présent
        yum install -y "$package"
    else
        echo "$package est déjà installé."
    fi
done

# Config sshd, save and remove root access
## save inital config file
cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
## Replace PermitRootLogin to no
sed -i 's/^PermitRootLogin.*$/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd
#Enable and start sshd as service
systemctl enable --now sshd

# Install Postfix
yum install postfix cyrus-sasl-lib cyrus-sasl-plain- y
# Enable and Start Postfix"
systemctl enable --now postfix

# Add rule to firewalld
echo -e "Add rule http/https/smtp to the firewalld"
firewall-cmd --zone=public --permanent --add-service=http
firewall-cmd --zone=public --permanent --add-service=https
firewall-cmd --zone=public --permanent --add-port=5050/tcp
firewall-cmd --reload

# Installing GitLab-ce"
# Définir l'URL par défaut
InputURL="http://127.0.0.1"

echo -e "\nInstalling GitLab"
EXTERNAL_URL="${InputURL}" yum install gitlab-ce.x86_64 -y
DIRECTORY="/etc/gitlab"

# Reset and change password Root, this operation may take some time
gitlab-rake 'gitlab:password:reset[root]' PASSWORD='rootme'


# Required step after editing the file /etc/gitlab/gitlab.rb
#After editing the /etc/gitlab/gitlab.rb run gitlab-ctl reconfigure"
#To start the service run gitlab-ctl start"
#To stop the service run gitlab-ctl stop"
#To reset a git user run (password gitlab-rake 'gitlab:password:reset[git_username1]')"
# How to configure SMTP
#For SMTP configuration show: https://docs.gitlab.com/omnibus/settings/smtp.html"

gitlab-ctl restart
