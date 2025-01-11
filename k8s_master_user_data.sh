#!/bin/bash
set -e

KUBERNETES_VERSION="${kubernetes_version}"
KUBERNETES_INSTALL_VERSION="${kubernetes_install_version}"
CONTAINERD_VERSION="${containerd_version}"
POD_CIDR="${pod_cidr}"
CLUSTER_NAME="${cluster_name}"

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release jq awscli ipset cron

curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y containerd.io=$CONTAINERD_VERSION*

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

apt-get update
apt-get install -y kubelet=$KUBERNETES_INSTALL_VERSION kubeadm=$KUBERNETES_INSTALL_VERSION kubectl=$KUBERNETES_INSTALL_VERSION
apt-mark hold kubelet kubeadm kubectl

cat >/etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

modprobe overlay
modprobe br_netfilter

cat >/etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

# Disable swap
swapoff -a
sed -i '/swap/d' /etc/fstab

REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
aws configure set region $REGION

LOCAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
hostname=$(hostname)
echo "$LOCAL_IP $hostname" >>/etc/hosts

if ! aws s3 ls "s3://${s3_bucket_name}/cluster_initialized" 2>&1 | grep -q 'cluster_initialized'; then
  echo "Initializing Kubernetes cluster as this is the first master node."
  aws s3 cp - s3://${s3_bucket_name}/cluster_initialized

  kubeadm_output=$(kubeadm init \
    --kubernetes-version $KUBERNETES_VERSION \
    --control-plane-endpoint="${api_dns}:6443" \
    --pod-network-cidr=$POD_CIDR \
    --apiserver-advertise-address=$LOCAL_IP \
    --upload-certs \
    --token-ttl=0 2>&1)

  echo "$kubeadm_output" >/root/kubeadm_init_output.txt
  aws s3 cp /root/kubeadm_init_output.txt s3://${s3_bucket_name}/kubeadm_init_output.txt

  control_plane_join=$(echo "$kubeadm_output" | grep -A 4 "control-plane node running the following command" | tail -n 3 | sed ':a;N;$!ba;s/\\\n//g')
  echo "$control_plane_join" >/root/control_plane_join.sh
  aws s3 cp /root/control_plane_join.sh s3://${s3_bucket_name}/control_plane_join.sh

  worker_join=$(echo "$kubeadm_output" | grep -A 3 "Then you can join any number of worker nodes" | tail -n 2 | sed ':a;N;$!ba;s/\\\n//g')
  echo "$worker_join" >/root/worker_join.sh
  aws s3 cp /root/worker_join.sh s3://${s3_bucket_name}/worker_join.sh

  export KUBECONFIG=/etc/kubernetes/admin.conf

  mkdir -p /root/.kube
  cp -i /etc/kubernetes/admin.conf /root/.kube/config
  chown $(id -u):$(id -g) /root/.kube/config

  kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml

  aws s3 cp /etc/kubernetes/admin.conf s3://${s3_bucket_name}/config

else

  # #############################
  # NEED SOME FIX
  # #############################

  echo "Another node is initializing or has initialized the cluster. Waiting to join as additional master..."

  while ! aws s3 ls "s3://${s3_bucket_name}/control_plane_join.sh" 2>/dev/null; do
    echo "Waiting for cluster initialization to complete..."
    sleep 10
  done

  aws s3 cp s3://${s3_bucket_name}/control_plane_join.sh /root/control_plane_join.sh
  chmod +x /root/control_plane_join.sh

  #     # Before joining, check if we need to clean up old etcd members
  #     if ! bash /root/control_plane_join.sh; then
  #         echo "Join failed, checking etcd members..."

  #         for ip in $(aws ec2 describe-instances --filters "Name=tag:k8s.io/cluster-autoscaler/$CLUSTER_NAME/Role,Values=master" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].PrivateIpAddress' --output text); do
  #             if curl -k https://$ip:2379/health 2>/dev/null | grep -q 'true'; then
  #                 WORKING_ETCD=$ip
  #                 break
  #             fi
  #         done

  #         if [ ! -z "$WORKING_ETCD" ]; then
  #             ETCDCTL_API=3 etcdctl --endpoints=https://$WORKING_ETCD:2379 \
  #                 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  #                 --cert=/etc/kubernetes/pki/etcd/server.crt \
  #                 --key=/etc/kubernetes/pki/etcd/server.key \
  #                 member list

  #             for member in $(ETCDCTL_API=3 etcdctl --endpoints=https://$WORKING_ETCD:2379 \
  #                 --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  #                 --cert=/etc/kubernetes/pki/etcd/server.crt \
  #                 --key=/etc/kubernetes/pki/etcd/server.key \
  #                 member list | grep unstarted | cut -d',' -f1); do

  #                 ETCDCTL_API=3 etcdctl --endpoints=https://$WORKING_ETCD:2379 \
  #                     --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  #                     --cert=/etc/kubernetes/pki/etcd/server.crt \
  #                     --key=/etc/kubernetes/pki/etcd/server.key \
  #                     member remove $member
  #             done
  #         else
  #             echo "No working etcd members found. Please check etcd health manually."
  #         fi

  #         bash /root/control_plane_join.sh
  #     fi

  #     # Schedule certificate renewal every hour
  #     cat > /root/renew_certs.sh <<EOF
  # #!/bin/bash
  # set -e
  # echo "Renewing certificates..."
  # new_cert=$(kubeadm init phase upload-certs --upload-certs | tail -n 1)
  # control_plane_join_certless=$(echo "$control_plane_join" | tail -n 1)
  # echo "$control_plane_join_certless" > /root/control_plane_join.sh
  # echo "$new_cert" >> /root/control_plane_join.sh
  # aws s3 cp /root/control_plane_join.sh s3://${s3_bucket_name}/control_plane_join.sh
  # EOF

  #     chmod +x /root/renew_certs.sh
  #     (crontab -l 2>/dev/null; echo "0 * * * * /root/renew_certs.sh") | crontab -

  export KUBECONFIG=/etc/kubernetes/admin.conf
  mkdir -p /root/.kube
  cp -i /etc/kubernetes/admin.conf /root/.kube/config
  chown $(id -u):$(id -g) /root/.kube/config

  aws s3 cp /etc/kubernetes/admin.conf s3://${s3_bucket_name}/config
fi

