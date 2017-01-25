#!/bin/bash

echo Envoking mySQL service and requesting version information as a Test 
echo of the service.
echo *******************************************************************

POD_NODE_IP=`kubectl describe pod mysql | grep Node | awk -F "/" '{ print $2 }'`

mysql -uroot -pyourpassword -h$POD_NODE_IP <<!
  show variables like '%version%';
!

