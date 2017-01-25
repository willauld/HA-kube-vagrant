#!/bin/bash

cd ~

set +x

echo kubectl get nodes
kubectl get nodes

mkdir -p pods
cd pods

cp /vagrant/mySQL/mysql_pod.yaml mysql.yaml

echo kubectl create -f mysql.yaml
kubectl create -f mysql.yaml

echo kubectl get pods
kubectl get pods

cp /vagrant/mySQL/mysql-service.yaml mysql-service.yaml

####
#### Need to modify the IP in the above yaml file
####
POD_NODE_IP=`kubectl describe pod mysql | grep Node | awk -F "/" '{ print $2 }'`
sed -i s/POD_NODE_IP/$POD_NODE_IP/  mysql-service.yaml

echo kubectl create -f mysql-service.yaml
kubectl create -f mysql-service.yaml

echo kubectl get services
kubectl get services

cd ..
