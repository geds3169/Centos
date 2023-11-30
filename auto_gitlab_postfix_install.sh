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

# Active le gestionnaire de configuration CRB
dnf config-manager --set-enabled crb

# install epel-release RPM
dnf install -y epel-release epel-next-release

# Installation des dépendances
sudo dnf install -y curl policycoreutils openssh-server perl

# Config sshd, save and remove root access
## save inital config file
cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
## Replace PermitRootLogin to no
sed -i 's/^PermitRootLogin.*$/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd
#Enable and start sshd as service
systemctl enable --now sshd

# Configuration du firewall
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-port=5050/tcp
firewall-cmd --reload

# Installation de postfix et activation en tant que service
dnf install -y postfix
systemctl enable --now postfix

# Ajout du repository GitLab CE
tee /etc/yum.repos.d/gitlab_gitlab-ce.repo > /dev/null <<EOL
[gitlab_gitlab-ce]
name=gitlab_gitlab-ce
baseurl=https://packages.gitlab.com/gitlab/gitlab-ce/el/8/\$basearch
repo_gpgcheck=1
gpgcheck=1
enabled=1
gpgkey=https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey
       https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey/gitlab-gitlab-ce-3D645A26AB9FBD22.pub.gpg
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300

[gitlab_gitlab-ce-source]
name=gitlab_gitlab-ce-source
baseurl=https://packages.gitlab.com/gitlab/gitlab-ce/el/8/SRPMS
repo_gpgcheck=1
gpgcheck=1
enabled=1
gpgkey=https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey
       https://packages.gitlab.com/gitlab/gitlab-ce/gpgkey/gitlab-gitlab-ce-3D645A26AB9FBD22.pub.gpg
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
metadata_expire=300
EOL

# Installation de GitLab CE
dnf install -y gitlab-ce

# Configuration du hostname
hostnamectl set-hostname devops.home

# Configuration de l'URL et du port dans le fichier de configuration GitLab
sed -i "s|external_url 'http://gitlab.example.com'|external_url 'https://devops.home:5050'|g" /etc/gitlab/gitlab.rb

# Configuration du mot de passe root
sed -i "s|gitlab_rails['initial_root_password'] = nil|gitlab_rails['initial_root_password'] = 'rootme'|g" /etc/gitlab/gitlab.rb

# Configuration de Let's Encrypt
sed -i "s|# letsencrypt['enable'] = nil|letsencrypt['enable'] = true|g" /etc/gitlab/gitlab.rb
sed -i "s|# letsencrypt['contact_emails'] = nil|letsencrypt['contact_emails'] = ['admin@example.com']|g" /etc/gitlab/gitlab.rb
sed -i "s|# letsencrypt['auto_renew'] = nil|letsencrypt['auto_renew'] = true|g" /etc/gitlab/gitlab.rb

# Reconfiguration de GitLab après modification du fichier de configuration
gitlab-ctl reconfigure
