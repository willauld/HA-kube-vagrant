#!/bin/bash

####
echo Configuring the Loadbalancer Node: kubeNode4
####

FIRST_CONTLR_INDX=$1
CONTLR_COUNT=$2
BASE_IP_STR=$3
ARRAY=()

for (( c=$FIRST_CONTLR_INDX,i=1; c<$FIRST_CONTLR_INDX+$CONTLR_COUNT; c++,i++ ))
do  
   #echo "string: CONTRLR$i=$BASE_IP_STR$c"
   ARRAY[$i]="$BASE_IP_STR$c"
   #echo ${ARRAY[$i]}
done

####
echo Configuring HAProxy
####

if [ ! -f /etc/haproxy/haproxy.cfg ]; then

  # Install haproxy
  sudo yum -y install haproxy
fi

  # Configure haproxy
  cat > /etc/default/haproxy <<EOD
# Set ENABLED to 1 if you want the init script to start haproxy.
ENABLED=1
EOD

  if [ ! -f /etc/haproxy/haproxy.cfg.orig ]; then
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.orig
  fi
  sudo cat > /etc/haproxy/haproxy.cfg <<EOD
global
    daemon
    maxconn 256

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

frontend http-in
    bind *:80
    default_backend webservers

backend webservers
    balance roundrobin
    option httpchk
    option forwardfor
    option http-server-close
    server kube_api0 ${ARRAY[1]}:80 check
    server kube_api1 ${ARRAY[2]}:80 check
    server kube_api2 ${ARRAY[3]}:80 check

frontend kubectl-https-in
    bind *:6443
    mode tcp
    default_backend kube-api

backend kube-api
    mode tcp
    balance roundrobin
    option httpchk
    option forwardfor
    option http-server-close
    server kube_api0 ${ARRAY[1]}:6443
    server kube_api1 ${ARRAY[2]}:6443
    server kube_api2 ${ARRAY[3]}:6443

frontend kubectl-https-in
    bind *:2379
    mode tcp
    default_backend etcd-api

backend etcd-api
    mode tcp
    balance roundrobin
    option httpchk
    option forwardfor
    option http-server-close
    server etcd_api0 ${ARRAY[1]}:2379
    server etcd_api1 ${ARRAY[2]}:2379
    server etcd_api2 ${ARRAY[3]}:2379

listen stats *:1936
    stats enable
    stats uri /
    stats hide-version
    stats auth user:password

EOD

echo Configuring HAProxy stats at port 1936 with USER: \'user\' PASSWD: \'password\'

/usr/sbin/service haproxy restart

