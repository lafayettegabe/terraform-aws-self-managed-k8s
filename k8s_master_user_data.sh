#!/bin/bash
set -e

AMI_ARCHITECTURE="${ami_architecture}"
KUBERNETES_VERSION="${kubernetes_version}"
KUBERNETES_INSTALL_VERSION="${kubernetes_install_version}"
CONTAINERD_VERSION="${containerd_version}"
POD_CIDR="${pod_cidr}"
CLUSTER_NAME="${cluster_name}"
EFS_ID="${efs_id}"

# ==============================================================================================
# =====================================   CONFIGURING  =========================================
# ==============================================================================================

# Update and install required packages
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release jq awscli ipset cron git

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
# =====================================   INITIALIZING =========================================
# ==============================================================================================

echo "Initializing Kubernetes cluster."

kubeadm_output=$(kubeadm init \
  --kubernetes-version $KUBERNETES_VERSION \
  --control-plane-endpoint="${api_dns}:6443" \
  --pod-network-cidr=$POD_CIDR \
  --apiserver-advertise-address=$LOCAL_IP \
  --upload-certs \
  --token-ttl=0 2>&1)
echo "$kubeadm_output" >/root/kubeadm_init_output.txt

# Extract the worker node join command
worker_join=$(echo "$kubeadm_output" | grep -A 3 "Then you can join any number of worker nodes" | tail -n 2 | sed ':a;N;$!ba;s/\\\n//g')
echo "$worker_join" >/root/worker_join.sh
aws s3 cp /root/worker_join.sh s3://${s3_bucket_name}/worker_join.sh
echo "Worker join script saved and uploaded to S3."

# Configure kubectl for admin
export KUBECONFIG=/etc/kubernetes/admin.conf
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown $(id -u):$(id -g) /root/.kube/config

# Deploy the network plugin (Kube-router)
kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml

# Save EFS ID as ConfigMap
kubectl create configmap efs-config --from-literal=efs-id=${efs_id}

# Save admin kubeconfig to S3 for later use
aws s3 cp /etc/kubernetes/admin.conf s3://${s3_bucket_name}/config

# ==============================================================================================
# =====================================   INSTALL HELM AND EFS =================================
# ==============================================================================================

# Install Helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor -o /usr/share/keyrings/helm-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/helm-keyring.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
apt-get update
apt-get install -y helm

# Add the aws-efs-csi-driver Helm repository
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update

# Install/upgrade the AWS EFS CSI Driver
helm upgrade --install aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
  --namespace kube-system \
  --set image.region=$REGION

echo "AWS EFS CSI Driver installed successfully."

# ==============================================================================================
# =====================================   COMPLETION ===========================================
# ==============================================================================================

echo "Kubernetes master setup is complete. Worker nodes can join using the script from S3."
