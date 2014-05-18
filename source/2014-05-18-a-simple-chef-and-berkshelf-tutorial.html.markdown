---
title: A simple Chef and Berkshelf tutorial
date: 2014-05-18
tags: Redis, nosql, AWS, Ruby on Rails
---

This is a simple tutorial explaining how to manage a Chef server and a node on two vagrant machines, using Berkshelf to manage an external cookbook with it's LWRP on the side.

This was used as the default setup for a cluster where it is advised to disable IPv6.

READMORE

<center>
# Chef, Berkshelf and a simple sysctl cookbook on Vagrant machines.
</center>

## Get the tutorial's kitchen repository

I have published a very simple Chef "kitchen" containing all the necessary code fpr this tutorial. It includes the configuration for the Vagrant machines, a default Chef configuration for the workstation, the Berksfile for the additional cookbooks and a homemade cookbook containing a sysctl setup disabling IPv6.

You can clone this repo with the following command :

    git clone git@github.com:jp/chef-kitchen-tutorial

## Boot the virtual machines

Install vagrant if necessary : https://docs.vagrantup.com/v2/installation/

    cd chef-kitchen-tutorial
    vagrant up

## Make ssh happy

  Two virtual machines are now launched. I advise to copy your public key in the machines for an easiest management.

    ssh-copy-id root@192.168.20.10
    ssh-copy-id root@192.168.20.12

## Install Chef Server

Log in 192.168.20.10 and follow the instructions here : http://docs.opscode.com/install_server.html

## Install Chef on your workstation

Instructions here : http://docs.opscode.com/chef/install_workstation.html
Or shorter :

    curl -L https://www.opscode.com/chef/install.sh | sudo bash

Note : ```gem install chef``` might be enough on your workstation.

## Get credentials from the chef server to setup the workstation

In order to have these knife commands working properly you need to get the authentication keys generated during the chef server install :

    scp root@192.168.20.10:/etc/chef-server/*.pem .chef/

## Bootstrap the node from the workstation

You can now bootstrap the node using knife.

    knife bootstrap 192.168.20.12 -x vagrant -P vagrant --sudo

## Check if the nodes are registered on the chef server

Your node should now be registered in your chef server. You can request the node list to check if everything worked fine.

    knife client list ## should output 'centos'

## Upload the cookbooks and the roles to the chef server

Berkshelf is here to help managing the external cookbooks. The only external cookbook used here is ![onehealth-cookbooks/sysct](https://github.com/onehealth-cookbooks/sysctl) It is here to manage the sysctl configuration of the server.

Note: during this process, I encountered ![this error](https://github.com/berkshelf/berkshelf/issues/11443) and as it is suggested in one comment, adding an entry in your /etc/hosts helps Berkshelf to connect to the Chef server. You might need to add ```192.168.20.10 chef``` in your /etc/hosts

    gem install berkshelf
    berks install
    berks upload
    knife upload .

## What's the home-made cookbook 'base_setup' ?

The home-made cookbook is here to use the LWRP of the sysctl cookbook, there are juste a ![few commands](https://github.com/jp/chef-kitchen-tutorial/blob/master/cookbooks/base_setup/recipes/default.rb) in it in order to setup the system :

    # disable IPv6
    sysctl_param 'net.ipv6.conf.all.disable_ipv6' do
      value 1
      notifies :run, 'ruby_block[save-sysctl-params]', :delayed
    end

## add cookbooks to the node's run list

Now all your cookbooks are on the Chef server. You can add them to you node's run list :

    knife node run_list add centos sysctl base_setup

## Run the cookbooks on the node

To process the run list on the node, you need to run the ```chef-client``` command as root. You can do this through ssh :

    ssh root@192.168.20.12 chef-client

## Validate

Now IPv6 should be disabled on your node. You can validate this with the following command. 0 means its enabled and 1 is disabled.

    ssh root@192.168.20.12 cat /proc/sys/net/ipv6/conf/all/disable_ipv6
