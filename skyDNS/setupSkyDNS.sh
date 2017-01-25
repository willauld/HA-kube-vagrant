#!/bin/bash

SERVER_IP=SERVER_IP_VAL #updated with sed

mkdir -p skyDNS
cd skyDNS

cp -v /vagrant/skyDNS/*.yaml . 

echo kubectl create -f services-kubedns.yaml
kubectl create -f services-kubedns.yaml

echo kubectl --namespace=kube-system get svc:::
kubectl --namespace=kube-system get svc

echo kubectl create -f deployment-kubedns.yaml
kubectl create -f deployment-kubedns.yaml

echo kubectl --namespace=kube-system get pods:::
kubectl --namespace=kube-system get pods


# should push this through the load balancer TODO
#curl -v --cacert ~/.kube/ca.pem -s https://${SERVER_IP}:2379/v2/keys/atomic.io/network/subnets | python -mjson.tool | grep -E "\{|\}|key|value"

#curl --cacert /path/to/ca.crt https://127.0.0.1:2379/v2/keys/foo -XPUT -d value=bar -v

cd ..
