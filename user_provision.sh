#!/bin/bash

####
echo Provisioning the USER at `pwd`
####

FIRST_CONTROLLER=$1
KUBERNETES_LB_IP=$2

echo provisioning USER STATION w/FirstController: $FIRST_CONTROLLER and LB: $KUBERNETES_LB_IP

##
## Create a user script to configure kubectl
##

cat > kubectl_remote_config.sh <<EOD

KUBERNETES_1st_IP=$FIRST_CONTROLLER
KUBERNETES_LB_IP=$KUBERNETES_LB_IP

if ! [ -f \$HOME/.kube/ca.pem ]; then
  mkdir -p \$HOME/.kube
  cp /vagrant/secrets/ca.pem \$HOME/.kube
fi

kubectl config set-cluster kubernetes-my-hard-way \\
  --certificate-authority=\$HOME/.kube/ca.pem \\
  --embed-certs=true \\
  --server=https://\${KUBERNETES_LB_IP}:6443

kubectl config set-credentials admin --token chAng3m3

kubectl config set-context default-context \\
  --cluster=kubernetes-my-hard-way \\
  --user=admin

kubectl config use-context default-context

####
echo now test to see the kubectl on host can talk to vagrant kubeNode cluster
####

echo kubectl cluster-info
kubectl cluster-info

echo kubectl get componentstatuses
kubectl get componentstatuses

echo kubectl get nodes
kubectl get nodes

echo "" #just add a blank line

EOD
chmod +x kubectl_remote_config.sh

# copy post cluster bring up test and setup scripts
cp -v /vagrant/mySQL/*.sh .
cat /vagrant/skyDNS/setupSkyDNS.sh | sudo sed -e s/SERVER_IP_VAL/${KUBERNETES_LB_IP}/ > ./setupSkyDNS.sh

## Move to /vagrant

cd /vagrant

if ! [ -f downloads/kubectl ]; then
  cd downloads
  wget https://storage.googleapis.com/kubernetes-release/release/v1.4.0/bin/linux/amd64/kubectl
  chmod +x kubectl
  cd ..
fi
sudo cp downloads/kubectl /usr/bin/

# install mysql clent in case we need it
sudo yum -y install mysql

