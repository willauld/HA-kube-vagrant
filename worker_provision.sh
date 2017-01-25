#!/bin/bash

####
echo "**** Provisioning worker node ****"
####

mkdir -p downloads

INTERNAL_IP=$1
FIRST_CONTLR_INDX=$2
CONTLR_COUNT=$3
BASE_IP_STR=$4
LB_INDEX=$5
ARRAY_ADDR=()

echo "**** Internal IP: $INTERNAL_IP            ****"
echo "**** First_controller: $FIRST_CONTLR_INDX ****"
echo "**** Number of controllers: $CONTLR_COUNT ****"
echo "**** Base string for IP: $BASE_IP_STR     ****"
echo "**** LB index: $LB_INDEX                  ****"

for (( c=$FIRST_CONTLR_INDX,i=1; c<$FIRST_CONTLR_INDX+$CONTLR_COUNT; c++,i++ ))
do
   #echo "string: CONTRLR$i=$BASE_IP_STR$c"
   ARRAY_ADDR[$i]="$BASE_IP_STR$c"
done

LB_IP=$BASE_IP_STR$LB_INDEX

echo "**** LoadBalancer IP: $LB_IP              ****"
echo "**** Controller endpoints: ${ARRAY_ADDR[1]},${ARRAY_ADDR[2]},${ARRAY_ADDR[3]} ****"


cd /vagrant
sudo mkdir -p /var/lib/kubernetes
sudo cp secrets/ca.pem secrets/kubernetes-key.pem secrets/kubernetes.pem /var/lib/kubernetes/

####
echo "**** Installing bridge-utils and Flannel ****"
####

#### ToDo: I don't think I need the bridge-utils any more is this true?
#sudo yum -y install bridge-utils

####
echo "**** Installing Flannel ****"
####

if ! [ -f downloads/flannel-v0.7.0-linux-amd64.tar.gz ]; then
  cd downloads
  wget https://github.com/coreos/flannel/releases/download/v0.7.0/flannel-v0.7.0-linux-amd64.tar.gz
  tar -xvf flannel-v0.7.0-linux-amd64.tar.gz
  cd ..
fi

sudo cp -v downloads/flanneld downloads/mk-docker-opts.sh /usr/bin/

sudo cat > /etc/systemd/system/flanneld.service <<EOD
[Unit]
Description=Flanneld overlay network agent
After=network.target
Before=docker.service
 
[Service]
Type=notify
#EnvironmentFile=/etc/sysconfig/flanneld
#EnvironmentFile=-/etc/sysconfig/docker-network
ExecStart=/usr/bin/flanneld \\
	-iface=${INTERNAL_IP} \\
	-public-ip=${INTERNAL_IP} \\
	-etcd-endpoints=https://${ARRAY_ADDR[1]}:2379,https://${ARRAY_ADDR[2]}:2379,https://${ARRAY_ADDR[3]}:2379 \\
	-etcd-prefix=/atomic.io/network/ \\
	-etcd-cafile=/var/lib/kubernetes/ca.pem 
ExecStartPost=/usr/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=on-failure
RestartSec=5s
 
[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOD

echo "&&&&&&&&&&&&&&&&&&&&&&&&&"
cat  /etc/systemd/system/flanneld.service
echo "&&&&&&&&&&&&&&&&&&&&&&&&&"

sudo systemctl daemon-reload
sudo systemctl enable flanneld
sudo systemctl restart flanneld

sudo systemctl status flanneld --no-pager

echo "**** $ ip a | grep flannel | grep inet::: ****"
ip a | grep flannel | grep inet

echo "&&&&&&&&&&&&&&&&&&&&&&&&&"
cat /run/flannel/subnet.env
echo "&&&&&&&&&&&&&&&&&&&&&&&&&"

####
echo "**** Installing Docker ****"
####

if ! [ -f downloads/docker-1.12.1.tgz ]; then
  cd downloads
  wget https://get.docker.com/builds/Linux/x86_64/docker-1.12.1.tgz
  tar -xvf docker-1.12.1.tgz
  cd ..
fi 
sudo cp -v downloads/docker/docker* /usr/bin/

source /var/run/flannel/subnet.env # This file is created by flanneld

echo "#############FLANNEL_SUBNET=${FLANNEL_SUBNET}############"
echo "#############FLANNEL_MTU   =${FLANNEL_MTU}   ############"

sudo cat > /etc/systemd/system/docker.service <<EOD
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io

After=flanneld.service
Requires=flanneld.service

[Service]
ExecStart=/usr/bin/docker daemon \\
  --iptables=false \\
  --ip-masq=false \\
  --host=unix:///var/run/docker.sock \\
  --log-level=error \\
  --bip=${FLANNEL_SUBNET} \\
  --mtu=${FLANNEL_MTU} \\
  --storage-driver=overlay
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOD

echo "&&&&&&&&&&&&&&&&&&&&&&&&&"
cat  /etc/systemd/system/docker.service
echo "&&&&&&&&&&&&&&&&&&&&&&&&&"

sudo systemctl daemon-reload
sudo systemctl enable docker.service
sudo systemctl restart docker.service

sleep 5
echo "**** docker version:: ****"
sudo docker version

echo "**** Test Cluster / Flannel Config ****"
ip -4 a | grep inet


####
echo "**** Download and install the Kubernetes worker binaries: ****"
####

if ! [ -f downloads/kubectl ]; then
  cd downloads
  wget https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kubectl
  chmod +x kubectl
  cd ..
fi

if ! [ -f downloads/kube-proxy ]; then
  cd downloads
  wget https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kube-proxy
  chmod +x kube-proxy
  cd ..
fi

if ! [ -f downloads/kubelet ]; then
  cd downloads
  wget https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kubelet
  chmod +x kubelet
  cd ..
fi

sudo cp downloads/kubectl downloads/kube-proxy downloads/kubelet /usr/bin/
sudo mkdir -p /var/lib/kubelet/

sudo cat > /var/lib/kubelet/kubeconfig <<EOD
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/ca.pem
    server: https://${LB_IP}:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet
  name: kubelet
current-context: kubelet
users:
- name: kubelet
  user:
    token: chAng3m3
EOD

#  --configure-cbr0=true \\
#  --network-plugin=cni \\
#

sudo cat > /etc/systemd/system/kubelet.service <<EOD
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/kubelet \\
  --address=${INTERNAL_IP} \\
  --hostname-override=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --api-servers=https://${ARRAY_ADDR[1]}:6443,https://${ARRAY_ADDR[2]}:6443,https://${ARRAY_ADDR[3]}:6443 \\
  --cloud-provider= \\
  --cluster-dns=10.32.0.10 \\
  --cluster-domain=cluster.local \\
  --container-runtime=docker \\
  --docker=unix:///var/run/docker.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --reconcile-cidr=true \\
  --serialize-image-pulls=false \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOD

echo "&&&&&&&&&&&&&&&&&&&&&&&&&"
cat /etc/systemd/system/kubelet.service
echo "&&&&&&&&&&&&&&&&&&&&&&&&&"

sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl start kubelet
sudo systemctl status kubelet --no-pager

####
echo "**** do kube proxy ****"
####

sudo cat > /etc/systemd/system/kube-proxy.service <<EOD
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-proxy \\
  --master=https://${ARRAY_ADDR[1]}:6443 \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --proxy-mode=iptables \\
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOD

echo "&&&&&&&&&&&&&&&&&&&&&&&&&"
cat /etc/systemd/system/kube-proxy.service
echo "&&&&&&&&&&&&&&&&&&&&&&&&&"


sudo systemctl daemon-reload
sudo systemctl enable kube-proxy
sudo systemctl start kube-proxy
sudo systemctl status kube-proxy --no-pager

