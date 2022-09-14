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
# Tester: Centos7 but maybe can work in Fedora
#
# Required: 2 core mini
#           2048 mo ram mini
#			static ip and dns configured
#			external rules firewall (pfsense (...) )
#
# To run the script: sudo bash ./deploy_gitlab_postfix_install.sh
# Review: Christophe Garcia
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
echo -e "\nThis script update system, install Postfix and Gitlab-ce\n\n"
sleep 1

echo -e "\nCleaning old entry"
yum clean all -y

echo -e "\nInstall GPG key elrepo"
rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org

echo -e "\nInstall the ELRepo Repository"

rpm -Uvh https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm

echo -e "\nUpdate sourcelist"
yum update -y

echo -e "\nEnabling the EPL repository"
yum install epel-release -y

# Upgrade kernel
# https://lunux.net/how-to-install-the-elrepo-repository-on-rhel-6-7-8-and-centos-6-7-8/

echo -e "\nInstall curl policy security and openssh-server and perl"
yum install -y curl policycoreutils-python.x86_64 openssh-server perl -y

# Thx Christophe Garcia add config sshd
cp -f /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
echo "Do you want to change the default port ssh (22) ? [y/n] : "
read -r CHANGE
if [ "${CHANGE}" == "yes" ] || [ "${CHANGE}" == "y" ]; then  
	echo -e "\nSSH port currently in use"
	semanage port -l | grep ssh
	echo -e "\nFill the port : "
	read -r PORT
	semanage port -a -t ssh_port_t -p tcp "${PORT}"
	# ADD rule to firewalld
	echo -e "\nIf you are using another firewall than firewalld add manually the rule for the new port ssh"
	firewall-cmd --add-port="${PORT}"/tcp --permanent
	echo -e "\nReload firewalld rules"
	firewall-cmd --reload
	echo -e "\nYou modify the configuration in /etc/ssh/sshd_config"
	#Test if exist "Port" and search Port or #Port
	ChangePort=$(cat /etc/ssh/sshd_config |nl -ba | grep "^.*[^#]Port[ \t][0-9]*$" |awk '{print $1}')
	if [ "${ChangePort}" != "" ]; then
			sed -i "${ChangePort}s/^(.*) [0-9]*$/\1 $PORT/" /etc/ssh/sshd_config
	else
		ChangePort=$(cat /etc/ssh/sshd_config |nl -ba | grep "^.*#Port[ \t]*[0-9]*$" |awk '{print $1}')
		if [ "${ChangePort}" != "" ]; then
			sed -i "${ChangePort}iPort $PORT" /etc/ssh/sshd_config
		else
			echo "Port $PORT" >> /etc/ssh/sshd_config
		fi
	fi
	sshd -t
	if [ $? -eq 0 ] ; then
		systemctl restart sshd
	else
		echo "Houston we have a problem, please check your sshd_config file" 
		exit 1
	fi
else
	echo -e "OK, We continue the work"
fi

echo "Do you want to change to remove Root access ? [y/n] : "
read -r RemoveRootAccess
if [ "${RemoveRootAccess}" == "yes" ] || [ "${RemoveRootAccess}" == "y" ]; then 
	PermitRootLogin=$(cat /etc/ssh/sshd_config |nl -ba | grep "^.*[^#\"]PermitRootLogin[ \t]*yes.*$" |awk '{print $1}')
	if [ "${PermitRootLogin}" != "" ]; then
			sed -i "${PermitRootLogin}s/^.*$/PermitRootLogin no/" /etc/ssh/sshd_config
	else
		PermitRootLogin=$(cat /etc/ssh/sshd_config |nl -ba | grep "^.*#PermitRootLogin.*$" |awk '{print $1}')
		if [ "${PermitRootLogin}" != "" ]; then
			sed -i "${PermitRootLogin}iPermitRootLogin no" /etc/ssh/sshd_config
		else
			echo "PermitRootLogin no" >> /etc/ssh/sshd_config
		fi
	fi
	echo "For more security add at the bottom of the file"
	echo "exemple:"
	echo "AllowUsers username1 username2@192.168.10.30"
	echo "AllowGroups group1 groupe2"
	echo -e "\e[01;31mBefore modify PasswordAuthentication from yes to no, add a ssh key with passphrase\e[0m"
	echo "https://www.man7.org/linux/man-pages/man5/sshd_config.5.html or type man sshd_config in your terminal"
	sshd -t
	if [ $? -eq 0 ] ; then
		systemctl restart sshd
	else
		echo "Houston we have a problem, please check your sshd_config file" 
		exit 1
	fi
fi

echo -e "\nEnable sshd as service"
systemctl enable sshd

echo -e "\nStarting sshd"
systemctl start sshd

# Install Postfix
echo -e "\nInstall Postfix (MTA - MAIL TRANSFER AGENT)"
yum install postfix cyrus-sasl-lib cyrus-sasl-plain- y

echo -e "\nStart Postfix"
systemctl start postfix

echo -e "\nEnabling Postfix service"
systemctl enable postfix

# Add rule to firewalld
echo -e "Add rule http/https/smtp to the firewalld"
firewall-cmd --zone=public --permanent --add-service=http
firewall-cmd --zone=public --permanent --add-service=https
firewall-cmd --zone=public --permanent --add-port=5050/tcp
firewall-cmd --reload

# Requires manual intervention
echo -e "\nInstalling GitLab-ce\n"

echo -e "\nFill in the full url like: http://exemple.com, or https where the gitlab will be accessible : "
read -r InputURL

echo -e "\nYou have input: ${InputURL} is this correct  ? [(y|yes)/(n|no)] : " # (n|no) or other key do no
read -r isCorrect

# Thx Christophe Garcia
isInstalled="false"
while [ "${isInstalled}" == "false" ]; do
	if [ "${isCorrect}" == "yes" ] || [ "${isCorrect}" == "y" ]; then
		echo -e "\nOk now we can install repository gitlab-ce from the script packages.gitlab.com"
		echo -e "\e[01;31mThis operation may take a few minutes, If the machine goes to the standby screen, simply press [enter].\e[0m"
		sleep 2
		curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash
		isInstalled="true"
	else
        echo -e "\nFill again the full URL ? : "
		read -r InputURL
		echo -e "\nYou have input: ${InputURL} is this correct  ? [(y|yes)] : "
		read -r isCorrect
    fi
done

echo -e "\nInstalling GitLab"
EXTERNAL_URL="${InputURL}" yum install gitlab-ce.x86_64 -y

# Requires manual intervention
echo -e "\nChanging the directory to change the root password of the gui web interface"
DIRECTORY="/etc/gitlab"
cd "${DIRECTORY}"
echo "$PWD"

echo "This operation may take some time"
gitlab-rake 'gitlab:password:reset[root]'

sleep 2
# Required step after editing the file /etc/gitlab/gitlab.rb
echo -e "\nAfter editing the /etc/gitlab/gitlab.rb run gitlab-ctl reconfigure"
echo -e "\nTo start the service run gitlab-ctl start"
echo -e "\nTo stop the service run gitlab-ctl stop"
echo -e "\nTo reset a git user run (password gitlab-rake 'gitlab:password:reset[git_username1]')"

# How to configure SMTP
echo -e "\nFor SMTP configuration show: \nhttps://docs.gitlab.com/omnibus/settings/smtp.html"

echo -e "\nEnd of the job"
