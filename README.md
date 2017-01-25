# HA-kube-vagrant

# HA (High Availability) multi-server Kubernetes implementation using Vagrant

Summary: This project constructs a kubernetes cluster with three controller a load balancer node and one or more worker nodes. It began based on [Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way). However, this uses Vagrant rather than Google or Amazon cloud. The networking is still not correct in that, as is, the cluster is not reachable from the outside. See the discussion below for more details. To work around this, I create a "user" VM that represents the computer the user would normally be working from. The user system is kubeNode0. Provisioning places some scripts in the home directory of this user system to work with the resulting kubernetes cluster. 

Current status:
* User's working sysetem (VM, kubeNode0)
* Three controlers running etcd, kube-apiserver, kube-controller-manager and kube-scheduler (VMs, kubeNode1-3)
* One Loadbalancer based on HAProxy (VM, kubeNode4)
* One or more worker nodes running flannel, docker, kubelet, kube-proxy (VMs, kubeNode5-...)
* Vagrant ``` network: Not quite right, I may be running into a bug here. All servers are connected with a "public_network" with static IP, all servers include the Vagrant NAT interface. Originally the controller server was also getting a "private_network" w/static IP. This was to enable connections with the host system. However, the private network does not seem to be doing its part at all. See below for a more complete discussion. ```
* May still be a bit glitchy, not much testing

Requirements:
* A system with VirtualBox and Vagrant installed.
* 4 GB of RAM
* ? GB of free disk space

Tested on:
* Host system Ubuntu 16.04

How to use:
* Clone the project and enter its new directory
* type "vagrant up"
* If all goes well you'll have several virtualbox VMs running a kubernetes cluster
* "vagrant ssh kubeNode0" this VM represents the user's working machine
* Then from inside machine0:
* "./kubectl_setup_remote.sh" to configure kubectl to work remotely
* "./setupMySQL.sh" to create the SQL service
* "./testMySQL.sh" This is to smoke test whether mySQL is working. This should result in some general version related information as output from mySQL if it is working properly.  
* "./setupSkyDNS.sh" 

Discussion:
My goal is to has several environments where I can explore the kubernetes infrastructure more completely. This project creates a HA (highly available) environment but still less complicated than what we would have in a production environment so we can see the individual parts work or not. The load balancer is not HA yet. 

There are two current issues that I have not been able to find solutions to:
* kubernetes networking not working well with vagrant
* skyDNS not coming up properly. 

Kubernetes networking issue began manifesting as: I used only a vagrant "private_network" with static IPs while developing the provisioning scripts and Vagrantfile. The cluster was reachable (including w/kubectl) from the host. Everything worked as expected until creating the first pod in the kubernetes cluster. At this point the state would remain in "pending" forever with no signs of any trouble other than there was no forward progress. I changed the vagrant network to "public_network" still with static IPs and the container is created properly. However, all connectivity from the host goes away. 

Because the IPs are on a different subnet (same LAN but using static IPs) than the host it is not accessable from the host. Anyway to regain the host connectivity I added a "private_network" on the controller. In this case the "public_network" precedes the "private_network" withing the Vagrantfile. This "private_network" does not seem to function properly. I can see it in the controller as expected and on the host I see a vboxnet interface but I can't ping the controller from the host or access it in any way. Other than this, the kubernetes cluster is still functioning properly while using kubectl from the controller. 

Rearranging the Vagrantfile to change the order of the "public_network" and "private_network" on the controller fixes the host access problem with the controller and the contoller comes up (seemingly OK) with all the controller codes working properly. However, when a worker machine comes up and is attempting to provision, they can't reach the controller (etcd) and so they fail to provision properly leaving the kubernetes cluster completely broken. It appears that vagrant, virtualbox or both have some bug with how the network is handled. Where these machines had been able to ping each other they cannot after the rearrangement.

As a work around I use an additional VM to function as the remote user machine so as to run kubectl from a machine that is not itself part of the kubernetes cluster. This is ugly and uses even more presous host resources but works for now. 

The skyDNS issue: writeup TBD

