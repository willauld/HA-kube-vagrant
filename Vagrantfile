Vagrant.require_version ">= 1.5"
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  base_ip_str = "10.240.0.1"
  first_controller = 1 # is the value of the last digit in the IP addr
  number_controllers = 3
  controller_endpoints = ""

  config.vm.box = "bento/centos-7.1"

  (0..6).each do |i|
    #config.vm.boot_mode = :gui
    config.vm.define "kubeNode#{i}" do |kubeNode|
      kubeNode.vm.provider :virtualbox do |v|
                v.name = "kubeNode#{i}"
                v.customize [
                    "modifyvm", :id,
                    "--name", "kubeNode#{i}",
                    "--memory", 1024,
                    #"--cableconnected1", "on",
                    #"--natdnshostresolver1", "on",
                    "--cpus", 1,
                ]
      end
      
      kubeNode.vm.hostname="kubeNode#{i}"
      machine_ip = "#{base_ip_str}#{i}"
      kubeNode.vm.network "public_network", 
        :bridge => "enp5s0", 
        ip: "#{machine_ip}"

      case "#{i}" 

	when "0"
	  puts "**** USE SCRIPT FOR USER's Station #{machine_ip} *****"
          lb_indx=first_controller+number_controllers
          kubeNode.vm.provision :shell, 
            path: "user_provision.sh",
            :args => "#{base_ip_str}#{first_controller} #{base_ip_str}#{lb_indx}"
	when "1", "2", "3"
          configuring_server = i
	  puts "**** USE SCRIPT FOR CONTROLLER  #{machine_ip} server# #{configuring_server} *****"
          # Forward port to the test web server on each controller
          kubeNode.vm.network "forwarded_port", guest: 80, host: "809#{i}"
          kubeNode.vm.provision :shell, 
            path: "controller_provision.sh",
            :args => "#{machine_ip} #{configuring_server} #{first_controller} #{number_controllers} #{base_ip_str}"

        when "4"
          puts "**** USE SCRIPT FOR LoadBalancer  #{machine_ip} *****"
          # Forward port for HAProxy instrentation web page and LB pages
          kubeNode.vm.network "forwarded_port", guest: 1936, host: 1936 
          kubeNode.vm.network "forwarded_port", guest: 80, host: "809#{i}"
          kubeNode.vm.provision :shell, 
            path: "loadballancer_provision.sh",
            :args => "#{first_controller} #{number_controllers} #{base_ip_str}"

        else # "kubeNode5", "kubeNode6", ...
          puts "**** USE SCRIPT FOR Worker nodes  #{machine_ip} *****"
          loadbalancerIndx = first_controller + number_controllers
          kubeNode.vm.provision :shell, 
            path: "worker_provision.sh",
            :args => "#{machine_ip} #{first_controller} #{number_controllers} #{base_ip_str} #{loadbalancerIndx}"
      end
    end
  end
end
