#!/bin/bash
#
# Auteur : guilhem Schlosser
# Date : Aout 2022
# Nom du fichier: deploy_kubernetes.sh
# Version 1.0.0 :
# title: deploy kubernetes
# Permet de:
# - Installer Kubernetes
# - kubectl-convert
# - Ajoute les règles de firewall nécessaire (firewalld uniquement)
#
# Ne permet pas:
# - n'installe pas les Nodes
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
# To run the script: sudo bash ./deploy_kubernetes.sh
#                    
####################################################################
# PID Shell script
echo -e "\nPID of this script: $$"
#Name of script
echo -e "\nThe name of the script is : $0"
#####################################################################
title="deploy kubernetes"
echo -e "\n\n\n${title}"
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
echo -e "\nThis script update system, install Kubernetes-ce\n\n"
sleep 1
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
echo -e "\ncheck update and update"
yum check-update
yum update -y

# Install tools before
echo -e "\nInstall some tools needed"
sudo yum install -y wget net-tools dig ca-certificates apt-transport-http apt-transport-https

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

# Install bash completion
echo -e "\Install bash completion"
yum install -y install bash-completion
source /usr/share/bash-completion/bash_completion
## Enable autocompletion for user and system
echo
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
## Reload current session of Shell
echo -e "\n Reloading the bash"
exec bash

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

# Configure Firewall
#The nodes, containers, and pods need to be able to communicate across the cluster to perform their functions.
echo -e "\nConfigure Firewall, opening the necessary ports"
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10251/tcp
sudo firewall-cmd --permanent --add-port=10252/tcp
sudo firewall-cmd --permanent --add-port=10255/tcp
sudo firewall-cmd --reload

echo -e "\n\nhttps://kubernetes.io/docs/reference/ports-and-protocols/"
sleep 2
echo -e "\n\nhttps://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management"
sleep 2
echo -e "\n\nhttps://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#verify-kubectl-configuration"
sleep 2
echo -e "\n\nThe task is accomplished, good day"
exit 0
