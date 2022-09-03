#!/bin/bash
#
# Auteur : guilhem Schlosser
# Date : Aout 2022
# Nom du fichier: deploy_gitlab_postfix_install.sh
# Version 1.0.0 :
# title: Self-hosted gitlab-ee
# Permet de:
# - Installer les mises à jour système
# - Installer postfix (non paramétré)
# - Installer gitlab
# - Ajoute les règles de firewall nécessaire (firewalld uniquement)
#
# Tester: Centos7
#
# Required: 2 core mini
#           2048 mo ram mini
#			static ip and dns configured
#			external rules firewall (pfsense (...) )
####################################################################
# PID Shell script
echo "PID of this script: $$"

#Name of script
echo "The name of the script is : $0"
#####################################################################
# Make sure only root or wheel group user can run this script
if [ "$(whoami)" != "root" ]; then
 echo "You are running the script as 'root'"
elif [ "$(whoami)" != "wheel" ]; then
 echo "You are running the script as 'wheel'"
else
 echo -e "\nPlease run script as root."
 exit 2
fi

#####################################################################

echo -e "\nThis script update system, install Postfix and Gitlab-ce\n\n"
sleep 1

# Print information system
sudo cat /etc/redhat-release


echo -e "\nCleaning old entry"
sudo yum clean all -y

echo -e "\nInstall GPG key elrepo"
sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org

echo -e "\nInstall the ELRepo Repository"

sudo rpm -Uvh https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm

echo -e "\nUpdate sourcelist"
sudo yum update -y

echo -e "\nEnabling the EPL repository"
sudo yum install epel-release -y

# Upgrade kernel
# https://lunux.net/how-to-install-the-elrepo-repository-on-rhel-6-7-8-and-centos-6-7-8/

echo -e "\nInstall curl policy security and openssh-server and perl"
sudo yum install -y curl policycoreutils-python.x86_64 openssh-server perl -y

echo "Do you want to change the default port ssh (22) ? [y/n] : "
read -r CHANGE
if [ "${CHANGE}" == "yes" ] || [ "${CHANGE}" == "y" ]; then 
	echo -e "\nSSH port currently in use"
	semanage port -l | grep ssh
	echo -e "\nFill the port : "
	read -r PORT
	sudo semanage port -a -t ssh_port_t -p tcp "${PORT}"
	# ADD rule to firewalld
	echo -e "\nIf you are using another firewall than firewallcmd add manually the rule for the new port ssh"
	sudo firewall-cmd --add-port="{PORT}"/tcp --permanent
	echo -e "Reload firewalld rules"
	sudo firewall-cmd --reload
	echo -e "\nYou need to change the configuration in /etc/ssh/sshd_config"
	echo "Next step is restart the service, run sudo systemctl restart sshd"
else
	echo -e "OK, We continue the work"
fi

echo -e "\nEnable sshd as service"
sudo systemctl enable sshd

echo -e "\nStarting sshd"
sudo systemctl start sshd

# Install Postfix
echo -e "\nInstall Postfix (MTA - MAIL TRANSFER AGENT)"
sudo yum install postfix -y

echo -e "\nStart Postfix"
sudo systemctl start postfix

echo -e "\nEnabling Postfix service"
sudo systemctl enable postfix

# Add rule to firewalld
echo -e "Add rule http/https/smtp to the firewalld"
sudo firewall-cmd --zone=public --permanent --add-service=http
sudo firewall-cmd --zone=public --permanent --add-service=https
sudo firewall-cmd --zone=public --permanent --add-service=smtp
sudo systemctl reload firewalld

# Requires manual intervention
echo -e "\nInstalling GitLab-ce\n"

echo -e "\nFill in the full url like: http://exemple.com, or https where the gitlab will be accessible : "
read -r InputURL

echo -e "\nYou have input: ${InputURL} is this correct  ? [yes/no] : "
read -r isCorrect

while :; do
    if [ "${isCorrect}" == "no" ] || [ "${isCorrect}" == "n" ]; then
        echo -e "\nFill again the full URL ? : "
		read -r InputURL
		break
    elif [ "${isCorrect}" == "yes" ] || [ "${isCorrect}" == "y" ]; then
		echo -e "\nOk now we can install repository gitlab-ce from the script packages.gitlab.com"
		curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | sudo bash
		break
		wait
	else
		break
    fi
done

echo -e "\nInstalling GitLab"
sudo EXTERNAL_URL="${InputURL}" yum install gitlab-ce.x86_64 -y

# Requires manual intervention
echo -e "\nChanging the directory to change the root password of the gui web interface"
DIRECTORY="/etc/gitlab"
cd "${DIRECTORY}"
echo "$PWD"

sudo gitlab-rake "gitlab:password:reset"

sleep 2
# Required step after editing the file /etc/gitlab/gitlab.rb
echo -e "\nAfter editing the /etc/gitlab/gitlab.rb run sudo gitlab-ctl reconfigure"
echo -e "\nTo start the service run sudo gitlab-ctl start"
echo -e "\nTo stop the service run sudo gitlab-ctl stop"

# How to configure SMTP
echo -e "\nFor SMTP configuration show: \nhttps://docs.gitlab.com/omnibus/settings/smtp.html"
