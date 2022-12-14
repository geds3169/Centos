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
# 	    Enable IPv6 if you use comment line 29-31
#           Change IP Master line 64
# To run the script: sudo bash ./Single_Master_kubernetes.sh
#
# NEED ALWAYS A FIX TO CHANGE THE /etc/hosts
####################################################################
# Function to open the ports required by K8s
function_firewall(){

echo -e "\nConfigure Firewall, opening the necessary ports"
port_tcp=("179 379-2380 5473 6443 10250 10251 10252 10255")
port_udp=("4789 8285 8472")
for i in ${port_tcp[*]}
do
firewall-cmd --add-port="${i}"/tcp --permanent
done
for i in ${port_udp[*]}
do
firewall-cmd --add-port="${i}"/udp --permanent
done
firewall-cmd --reload

echo -e "\nhere is the list of open ports\n"
firewall-cmd --permanent --list-ports 
}

#NODE MASTERS
title="Install Kubernetes on the master"
echo -e "$\n\n\n\n{title}\n\n"

#####################################################
#	Comment these lines if you want to use IPv6
#####################################################
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf 

############################################
#	REPLACE IP ADDRESS (private) MASTER
############################################
MASTER="192.168.30.28"

# Update system
yum check-update -y
yum update -y
yum install -y install epel-release curl policycoreutils-python.x86_64


if [ "$(rpm -qf `which docker`)" != "" ]; then
	echo "Docker is installed" ;
else
	echo "Docker isnot installed";
	echo "Docker is not present and will be installed"
	# Download repository Docker
	echo "Add repository and install Docker"
	curl -fsSL https://get.docker.com | bash
	systemctl enable docker
	systemctl start docker
fi

# Install repository kubernetes
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# pass SELinux in mode permissive
setenforce 0
# Replace the value in the file
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Install K8s softwares
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Call the function
function_firewall
systemctl stop firewalld

# Enable kubelet service
systemctl enable --now kubelet

# Letting iptable see bridged traffic
cat << EOF | tee /etc/modules-load.d/k8s.config
br_netfilter
EOF

cat << EOF | tee /etc/sysctl.d/99-k8s.conf
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
EOF

sysctl -p /etc/sysctl.d/99-k8s.conf

# Fix Kubernetes
#sed -i "s/cgroupDriver: systemd/cgroupDriver: cgroupfs/g" /var/lib/kubelet/config.yaml

systemctl daemon-reload
systemctl restart kubelet


tee /etc/docker/daemon.json <<EOF
{
        "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

systemctl daemon-reload
systemctl restart docker containerd

# First diasbale swap
sudo swapoff -a

# And then to disable swap on startup in /etc/fstab
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Network declaration for pods
# private address ${MASTER} and pod network adress
kubeadm init --apiserver-advertise-address="${MASTER}" --pod-network-cidr=10.0.0.0/16 > init.out 

# Create a folder if not exists
mkdir -p /root/.kube

# Create a link symbolik of the config
if [ ! -L /root/.kube/config ]; then
	ln -s /etc/kubernetes/admin.conf /root/.kube/config
fi

# Restart Firewall
systemctl start firewalld

#Si ça fail faire:
# kubeadm reset puis y
#puis a nouveau
#kubeadm init --v=5

#Récupérer le code ou:
# export KUBECONFIG=/etc/kubernetes/admin.config

# Faire:
# kubectl get nodes
# Pour s'assurer que les nodes sont bien remontés
# Puis:
# kubectl get pods --all-namespaces

