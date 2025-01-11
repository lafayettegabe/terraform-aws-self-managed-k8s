#!/bin/bash
set -e

AMI_ARCHITECTURE="${ami_architecture}"
KUBERNETES_VERSION="${kubernetes_version}"
KUBERNETES_INSTALL_VERSION="${kubernetes_install_version}"
CONTAINERD_VERSION="${containerd_version}"

# ==============================================================================================
# =====================================   CONFIGURING  =========================================
# ==============================================================================================

# Update and install required packages
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release jq awscli

# Add Docker repository and install Docker
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
if [ "$AMI_ARCHITECTURE" == "arm" ]; then
  echo "Using ARM64 architecture for Docker"
  echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
else
  echo "Using AMD64 architecture for Docker"
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
fi

# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# Install containerd
apt-get update
apt-get install -y containerd.io=$CONTAINERD_VERSION*

# Configure containerd with systemd as the cgroup driver
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart and enable containerd
systemctl restart containerd
systemctl enable containerd

# Install Kubernetes components
apt-get update
apt-get install -y kubelet=$KUBERNETES_INSTALL_VERSION kubeadm=$KUBERNETES_INSTALL_VERSION kubectl=$KUBERNETES_INSTALL_VERSION
apt-mark hold kubelet kubeadm kubectl

# Configure kernel settings for Kubernetes networking
cat >/etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# Load necessary kernel modules
modprobe overlay
modprobe br_netfilter

# Ensure modules are loaded on boot
cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

# Disable swap (required by Kubernetes)
swapoff -a
sed -i '/swap/d' /etc/fstab

# Set AWS region and local IP
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
aws configure set region $REGION
LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Add local IP to /etc/hosts
hostname=$(hostname)
echo "$LOCAL_IP $hostname" >>/etc/hosts

# ==============================================================================================
# ======================================    JOINING    =========================================
# ==============================================================================================

# Wait until the master node provides the worker join script in S3
while ! aws s3 ls "s3://${s3_bucket_name}/worker_join.sh" 2>/dev/null; do
  echo "Waiting for cluster initialization to complete..."
  sleep 10
done

# Download the worker join script from S3
aws s3 cp s3://${s3_bucket_name}/worker_join.sh /root/worker_join.sh
chmod +x /root/worker_join.sh

# Execute the join script to connect this node to the cluster
bash /root/worker_join.sh
