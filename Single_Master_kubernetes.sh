#!/bin/bash
#
# Auteur : guilhem Schlosser
# Date : Aout 2022
# Nom du fichier: Single_Master_kubernetes.sh
# Version 1.0.0 :
# title: deploy kubernetes
# Permet de:
# - Installer Kubernetes
# - kubectl-convert
# - Ajoute les règles de firewall nécessaire (firewalld uniquement)
#
# Ne permet pas:
# - n'installe pas les Nodes, (nécessite le second script)
# - n"installe pas Docker-ce
# - n'installe pas Jenkins
# - ne configure pas le fichier /etc/hosts
#
# Tester: Centos7 but maybe can work in Fedora
#
# Required: x64 Centos7
#           root privileges
#           Replace under # CHANGE THE VALUE FQDN #
#           
# To run the script: sudo bash ./Single_Master_kubernetes.sh
#
# NEED ALWAYS A FIX TO CHANGE THE /etc/hosts
####################################################################
# PID Shell script
echo -e "\nPID of this script: $$"
#Name of script
echo -e "\nThe name of the script is : $0"
#####################################################################
title="deploy kubernetes"
subtitle="This installation is for a single control-plane cluster"
echo -e "\n\n\n${title}"
echo -e "\n\n${subtitle}\n"
sleep 2
#####################################################################
# Prevent execution: test Os & Print information system
if [ -f /etc/redhat-release ]; then
	cat /etc/redhat-release
else
	echo -e "\nDistribution is not supported"
	exit 1
fi
#####################################################################
# Make sure only root user can run this script
if [[ $EUID -ne 0 ]]; then
   echo -e "\nThis script must be run as root" 
   exit 1
fi
#####################################################################
# Add repository kubernetes
echo -e "Installing the repository kubernetes" 
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

yum clean all && yum -y makecache
yum install -y update
yum install -y curl policycoreutils-python.x86_64

# This part is not used for the moment, need a fix
: '
##########################################
#       CHANGE THE VALUE FQDN            #
##########################################
HOSTNAME="kubernetes.web-connectivity.fr"
##########################################

# Source function https://gist.github.com/irazasyed/a7b0a079e7727a4315b9 (many thanks)                                      

function removehost() {
    if [ -n "$(grep $HOSTNAME /etc/hosts)" ]
    then
        echo "$HOSTNAME Found in your $ETC_HOSTS, Removing now...";
        sed -i".bak" "/$HOSTNAME/d" $ETC_HOSTS
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
             -- sh -c -e "echo '$HOSTS_LINE' >> /etc/hosts";

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
echo -e "\ncheck update and update"
yum check-update
yum update -y

# Update the system
yum -y install epel-release

# Install tools before
echo -e "\nInstall some tools needed"

# Download the lasted stable kebectl binary & checksum file with curl
echo -e "\nDownload the lasted stable kebectl binary"
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

# Validate the binary against checksum file
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
# Check the the validity or quit the script
if [ $? -eq 1 ] 
then
    echo -e "\n There seems to be a problem between the binary file and the control file."
    # Script output in terminal after closing script
    tput smcup
    "$@"
    status=$?
    tput rmcup
    exit $status
fi

#Install kubetcl
echo -e "\nInstall kubetcl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Print the version
echo -e "\nHere is the current version installed"
kubectl version --client
sleep 5

# Show kubectl config
echo -e "\nhere is the current kubectl config"
kubectl cluster-info
sleep 5

# Install kubectl convert plugin
echo -e "\nInstall kubectl convert plugin"
## which allows you to convert manifests between different API versions. This can be particularly helpful to migrate manifests to a non-deprecated api version with newer Kubernetes release
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl-convert"
## Validate the binary
## Download the kubectl-convert checksum file
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl-convert.sha256"
## Validate the output
if [ $? -eq 1 ]; then
	echo -e "\nThere seems to be a problem between the binary file and the control file."
fi

# Install kubectl-convert
install -o root -g root -m 0755 kubectl-convert /usr/local/bin/kubectl-convert
kubectl convert --help
if [ $? -eq 1 ]; then
	echo -e "\nAn error has occurred."
fi

function firewall(){
# Configure Firewall
#The nodes, containers, and pods need to be able to communicate across the cluster to perform their functions.
echo -e "\nConfigure Firewall, opening the necessary ports"
port_tcp="179,2379-2380,5473,6443,10250,10251,10252,10255"
port_udp="4789,8285,8472"
firewall-cmd --permanent --add-port="${port_tcp}"/tcp --permanent
firewall-cmd --permanent --add-port="${port_udp}"/udp --permanent
firewall-cmd --reload

echo -e "\nhere is the list of open ports\n"
firewall-cmd --permanent --zone=public --list-ports 
}

# Open port call the function
firewall()

# Set SELinux in permissive mode (effectively disabling it)
## This is required to allow containers to access the host filesystem, which is needed by pod networks for example.
## You have to do this until SELinux support is improved in the kubelet.
## You can leave SELinux enabled if you know how to configure it but it may require settings that are not supported by kubeadm.

echo -e "\nChanging Selinux to permissive mode, but you can change it later"
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Install kubeadm
echo -e "\nInstalling kubelet and kubeadm"
yum -y install kubelet kubeadm --disableexcludes=kubernetes

# Turn off swap
echo -e "\nTurning off the Swap improve performance"
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a

# Enable service kubelet
echo -e "\nEnable service kubelet"
systemctl enable --now kubelet

#Configure systctl

modprobe overlay
modprobe br_netfilter

#Letting iptables see bridged traffic
## As a requirement for your Linux Node’s iptables to correctly see bridged traffic.
tee <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

echo -e "\nRestarting the kubelet "
systemctl daemon-reload
systemctl restart kubelet

# Install bash completion
echo -e "\Install bash completion"
yum install -y install bash-completion
source /usr/share/bash-completion/bash_completion
## Enable autocompletion for user and system
echo
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
## Reload current session of Shell
echo -e "\n Reloading the bash"
exec bash

sleep 2
echo -e "\n\n\nNow go to the nodes and install container runtime"
echo -e "\n\nThe master has been installed, Have a nice day"

exit 0
