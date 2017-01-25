#!/usr/bin/env bash

set -x 

mkdir -p downloads

INTERNAL_IP=$1
SERVER_NUM=$2
FIRST_CONTLR_INDX=$3
CONTLR_COUNT=$4
BASE_IP_STR=$5
ARRAY_SINDX=()
ARRAY_ADDR=()

LAST_CONTLR_INDX=$(( ${FIRST_CONTLR_INDX} + ${CONTLR_COUNT} -1 ))
echo LAST_CONTLR_INDX: $LAST_CONTLR_INDX

for (( c=$FIRST_CONTLR_INDX,i=1; c<$FIRST_CONTLR_INDX+$CONTLR_COUNT; c++,i++ ))
do
   #echo "string: CONTRLR$i=$BASE_IP_STR$c"
   ARRAY_SINDX[$i]="$i"
   ARRAY_ADDR[$i]="$BASE_IP_STR$c"
   #echo ${ARRAY_ADDR[$i]} ${ARRAY_SINDX[$i]}
done


echo $0 provisioning server $SERVER_NUM at $INTERNAL_IP

# Do this work in /vagrant
cd /vagrant

####
####
####
echo Provisioning etcd
####
####
####

sudo mkdir -p /etc/etcd/
sudo cp secrets/ca.pem secrets/kubernetes-key.pem secrets/kubernetes.pem /etc/etcd/

if ! [ -f downloads/etcd-v3.0.10-linux-amd64.tar.gz ]; then
  cd downloads
  wget https://github.com/coreos/etcd/releases/download/v3.0.10/etcd-v3.0.10-linux-amd64.tar.gz
  tar -xvf etcd-v3.0.10-linux-amd64.tar.gz
  cd ..
fi
sudo cp downloads/etcd-v3.0.10-linux-amd64/etcd* /usr/bin/
sudo mkdir -p /var/lib/etcd #### Back with persistant disk in production

ETCD_NAME=kubeNode$(echo $INTERNAL_IP | cut -c 11-)
echo "Configuring etcd systemd config file:" $INTERNAL_IP $ETCD_NAME

### ToDo TODO
if [ "$1" == "test_cluster_id_gen" ]; then ## not $1 fixme
  echo "@@@@@@@@@@@@@ ERROR WIP CODE SHOULD NOT EXECUTE @@@@@@@@@@@@@@@@@"
  if [ $SERVER_NUM == "1" ]; then 
    CLUSTER_TOKEN=$(uuidgen) 
    echo $CLUSTER_TOKEN > CLUSTER_TOKEN
  fi
  if [ -f CLUSTER_TOKEN ]; then
    CLUSTER_TOKEN=`cat CLUSTER_TOKEN`
  else
    echo ERROR: no CLUSTER_TOKEN file exitst
    exit 1;
  fi
  if [ $SERVER_NUM == $LAST_CONTLR_INDX ]; then
    #### TODO ToDo
    #### doing this at this point means I will not be able to reload after this
    #### Probably not a good idea, keep thinking
    rm -f CLUSTER_TOKEN
  fi
else
  CLUSTER_TOKEN="etcd-cluster-0" ## Generic cluster token
fi

sudo cat > /etc/systemd/system/etcd.service <<EOD
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/bin/etcd --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token ${CLUSTER_TOKEN} \\
  --initial-cluster kubeNode${ARRAY_SINDX[1]}=https://${ARRAY_ADDR[1]}:2380,kubeNode${ARRAY_SINDX[2]}=https://${ARRAY_ADDR[2]}:2380,kubeNode${ARRAY_SINDX[3]}=https://${ARRAY_ADDR[3]}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOD

echo "&&&&&&&&&&&&&&&&&&&&"
cat /etc/systemd/system/etcd.service
echo "&&&&&&&&&&&&&&&&&&&&"

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

# varify
sudo systemctl status etcd --no-pager 

####
####
####
echo Provisioning kubernetes control plain
####
####
####

sudo mkdir -p /var/lib/kubernetes
sudo cp secrets/ca.pem secrets/kubernetes-key.pem secrets/kubernetes.pem /var/lib/kubernetes/

if ! [ -f downloads/kube-apiserver ]; then
  cd downloads
  wget https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kube-apiserver
  chmod +x kube-apiserver
  cd ..
fi
if ! [ -f downloads/kube-controller-manager ]; then
  cd downloads
  wget https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kube-controller-manager
  chmod +x kube-controller-manager
  cd ..
fi
if ! [ -f downloads/kube-scheduler ]; then
  cd downloads
  wget https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kube-scheduler
  chmod +x kube-scheduler
  cd ..
fi
if ! [ -f downloads/kubectl ]; then
  cd downloads
  wget https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kubectl
  chmod +x kubectl
  cd ..
fi

#Install the Kubernetes binaries:

sudo cp -v downloads/kube-apiserver downloads/kube-controller-manager downloads/kube-scheduler downloads/kubectl /usr/bin/

####
echo Setup Authentication and Authorization
####

if ! [ -f downloads/token.csv ]; then
  cd downloads
  wget https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/token.csv
  cd ..
fi

sudo cp -v downloads/token.csv /var/lib/kubernetes/

if ! [ -f downloads/authorization-policy.jsonl ]; then
  cd downloads
  wget https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/authorization-policy.jsonl
  cd ..
fi

sudo cp downloads/authorization-policy.jsonl /var/lib/kubernetes/

####
echo Set up the API server
####

sudo cat > /etc/systemd/system/kube-apiserver.service <<EOD
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-apiserver \\
  --admission-control=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --authorization-mode=ABAC \\
  --authorization-policy-file=/var/lib/kubernetes/authorization-policy.jsonl \\
  --bind-address=${INTERNAL_IP} \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --insecure-bind-address=0.0.0.0 \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --etcd-servers=https://${ARRAY_ADDR[1]}:2379,https://${ARRAY_ADDR[2]}:2379,https://${ARRAY_ADDR[3]}:2379 \\
  --service-account-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --token-auth-file=/var/lib/kubernetes/token.csv \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOD

echo "&&&&&&&&&&&&&&&&&&&&"
cat /etc/systemd/system/kube-apiserver.service
echo "&&&&&&&&&&&&&&&&&&&&"

sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver
sudo systemctl start kube-apiserver

echo sudo systemctl status kube-apiserver --no-pager:
sudo systemctl status kube-apiserver --no-pager

####
echo Set up the manager server
####

sudo cat > /etc/systemd/system/kube-controller-manager.service <<EOD
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-controller-manager \\
  --allocate-node-cidrs=true \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --leader-elect=true \\
  --master=http://${INTERNAL_IP}:8080 \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOD

echo "&&&&&&&&&&&&&&&&&&&&"
cat /etc/systemd/system/kube-controller-manager.service
echo "&&&&&&&&&&&&&&&&&&&&"

sudo systemctl daemon-reload
sudo systemctl enable kube-controller-manager
sudo systemctl start kube-controller-manager

echo sudo systemctl status kube-controller-manager --no-pager:
sudo systemctl status kube-controller-manager --no-pager

####
echo Set up the scheduler server
####

sudo cat > /etc/systemd/system/kube-scheduler.service <<EOD
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-scheduler \\
  --leader-elect=true \\
  --master=http://${INTERNAL_IP}:8080 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOD

echo "&&&&&&&&&&&&&&&&&&&&"
cat /etc/systemd/system/kube-scheduler.service
echo "&&&&&&&&&&&&&&&&&&&&"

sudo systemctl daemon-reload
sudo systemctl enable kube-scheduler
sudo systemctl start kube-scheduler

echo sudo systemctl status kube-scheduler --no-pager:
sudo systemctl status kube-scheduler --no-pager

# Install apache
sudo yum -y install httpd

sudo cat > /var/www/html/index.html <<EOD
<html><head><title>${HOSTNAME}</title></head><body><h1>${HOSTNAME}</h1>
<p>This is the default web page for ${HOSTNAME}.</p>
</body></html>
EOD

sudo systemctl restart httpd.service
sudo systemctl enable httpd.service

#####
#####
#####

if [ $SERVER_NUM == $LAST_CONTLR_INDX ]; then 

#####
##### runs after the kubernetes control plain servers have been configured
##### and hence etcd should be fully up and running.
#####
##### So place the Flannld information in etcd prior to flanneld seeking it
##### but after etcd is up.
#####

echo "                  ******************************"
echo "                  **** etcdctl insert:   *******"
echo "                  ******************************"

# Somewhere, after etcd is up, the following command MUST be run
etcdctl --ca-file=/etc/etcd/ca.pem mk /atomic.io/network/config '{"Network":"10.200.0.0/16"}'

echo etcdctl --ca-file=/etc/etcd/ca.pem get /atomic.io/network/config:::
etcdctl --ca-file=/etc/etcd/ca.pem get /atomic.io/network/config 

echo "                  ******************************"
echo "                  **** etcdctl insert done *****"
echo "                  ******************************"

####
echo Verify Control plain is working
####

echo kubectl get componentstatuses:
kubectl get componentstatuses

fi
