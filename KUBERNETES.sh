#!/bin/bash
#
# Auteur : guilhem Schlosser
# Date : Aout 2022
# Nom du fichier: deploy_kubernetes.sh
# Version 1.0.0 :
# title: deploy kubernetes
# Permet de:
# - Installer Kubernetes
# - Ajoute les règles de firewall nécessaire (firewalld uniquement)
#
# Ne permet pas:
# - La mise en place d'un cluster Kubernetes
#
# Tester: Centos7 but maybe can work in Fedora
#
# Required: x64 Centos7
#           root privileges
#           a containerization engine (Docker), same machine or another
#           Replace line 56 by correct NAME.DOMAIN
#           
# To run the script: sudo bash ./deploy_kubernetes.sh
#                    
####################################################################
# PID Shell script
echo "PID of this script: $$"
#Name of script
echo "The name of the script is : $0"
#####################################################################
# Prevent execution: test Os & Print information system
if [ -f /etc/redhat-release ]; then
	cat /etc/redhat-release
else
	echo "Distribution is not supported"
	exit 1
fi
#####################################################################
# Make sure only root user can run this script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi
#####################################################################
echo -e "\nThis script update system, install Kubernetes-ce\n\n"
sleep 1
yum install -y update
yum install -y curl policycoreutils-python.x86_64

##########################################
#       CHANGE THE VALUE FQDN            #
##########################################
HOSTNAME="kubernetes.web-connectivity.fr"
##########################################
#                                        #
##########################################

: '
# Source function https://gist.github.com/irazasyed/a7b0a079e7727a4315b9 (many thanks)
function removehost() {
    if [ -n "$(grep $HOSTNAME /etc/hosts)" ]
    then
        echo "$HOSTNAME Found in your $ETC_HOSTS, Removing now...";
        sudo sed -i".bak" "/$HOSTNAME/d" $ETC_HOSTS
    elif [ -n "$(grep $IP /etc/hosts)" ]
        echo "$IP Found in your $ETC_HOSTS, Removing now...";
    else
        echo "$HOSTNAME was not found in your $ETC_HOSTS";
        echo "$IP was not found in your $ETC_HOSTS";
    fi
}

function addhost() {
    HOSTS_LINE="$IP\t$HOSTNAME"
    if [ -n "$(grep $HOSTNAME /etc/hosts)" ]
        then
            echo "$HOSTNAME already exists : $(grep $HOSTNAME $ETC_HOSTS)"
        else
            echo "Adding $HOSTNAME to your $ETC_HOSTS";
            sudo -- sh -c -e "echo '$HOSTS_LINE' >> /etc/hosts";

            if [ -n "$(grep $HOSTNAME /etc/hosts)" ]
                then
                    echo "$HOSTNAME was added succesfully \n $(grep $HOSTNAME /etc/hosts)";
                else
                    echo "Failed to Add $HOSTNAME, Try again!";
            fi
    fi
}

# PATH TO YOUR HOSTS FILE
ETC_HOSTS="/etc/hosts"
# DEFAULT IP FOR HOSTNAME
IP="$(hotname -I)"
# RETURN HOSTNAME
TEST_HOSTNAME="$(hotname -f)"
HOSTS_LINE="$IP\t$HOSTNAME"

if [ "${TEST_HOSTNAME}" == ${HOSTNAME} ]; then
    echo "The /etc/hosts file already contains the right values"
else
    echo "The /etc/hosts file has the wrong values and will be modified with the information you modified in this script (line 54)"
    removehost
    addhost
fi
'

# Update system
yum check-update
yum update -y


# Install Repository
touch /etc/yum.repos.d/kubernetes.repo
tee -a /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

#Install kubelet, kubeadm, and kubectl
sudo yum install -y kubelet kubeadm kubectl

# Enable and start service kubelet
systemctl enable kubelet
systemctl start kubelet

#Check success installation and depenency
if [ $? -eq 0 ]; then
   echo "Installation successs"
else
   echo "An error has occurred, the script will be exited, please take a look at your system"
fi

# Configure Firewall
#The nodes, containers, and pods need to be able to communicate across the cluster to perform their functions.
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10251/tcp
sudo firewall-cmd --permanent --add-port=10252/tcp
sudo firewall-cmd --permanent --add-port=10255/tcp
sudo firewall-cmd --reload

# Information for each worker node
echo -e "\n\nEnter the following commands on each worker node\n"
sleep 1
echo "sudo firewall-cmd --permanent --add-port=10251/tcp"
echo "sudo firewall-cmd --permanent --add-port=10255/tcp"
echo -e "\nfirewall-cmd --reload\n"
echo -e "\nMaybe you need to update Iptables (look the script line 160 - 166)\n"
sleep 5

# Update Iptables
# Set the net.bridge.bridge-nf-call-iptables to '1' in your sysctl config file. This ensures that packets are properly processed by IP tables during filtering and port forwarding.
#cat <<EOF > /etc/sysctl.d/k8s.conf
#net.bridge.bridge-nf-call-ip6tables = 1
#net.bridge.bridge-nf-call-iptables = 1
#EOF
#sysctl --system


# Disable SWAP
sudo sed -i '/swap/d' /etc/fstab
sudo swapoff -a

echo "Do you want the script to modify Selinux  ? [y/n] : "
read -r CHANGE_SELINUX
if [ "${CHANGE_SELINUX}" == "yes" ] || [ "${CHANGE_SELINUX}" == "y" ]; then 
    # The containers need to access the host filesystem, modificate the SELinux to permissive mode permanently
    sed -i s/^SELINUX=.*$/SELINUX=permissive/ /etc/selinux/config
    setenforce 0
    sleep 1
    echo "Reboot manualy the system to save the changes permanently"
    echo "Use the getenforce command to display the status of SELinux"
    echo -e "\nThe task is accomplished, good day"
    sleep 1
    exit 0
else
    echo -e "\nThe containers need to access the host filesystem, modificate the SELinux to permissive mode permanently"
    sleep 1
    echo -e "\nThe task is accomplished, good day"
    exit 0
fi
