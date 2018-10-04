Install using Vagrant
====================================================

In case you want an isolated environment with automated installation
for development or testing with Sphinx running, you could use Vagrant in conjunction Virtualbox.

NOTE: Instructions below are tested on Ubuntu 18.04 (bionic).

Install the latest version of Virtualbox
-----------------------

    sudo apt update
    sudo apt install virtualbox dkms

Install the latest version of Vagrant and guest plugin for it
-----------------------
The version of vagrant that comes with ubuntu had [issues](https://github.com/hashicorp/vagrant/issues/9788) for me.
Instead i used the latest directly from vagrant:

    cd /tmp && wget https://releases.hashicorp.com/vagrant/2.1.5/vagrant_2.1.5_x86_64.deb
    sudo dpkg -i vagrant_2.1.5_x86_64.deb
    vagrant plugin install vagrant-vbguest

Install NFS for folders and code synchronization
-----------------------

    sudo apt-get install nfs-kernel-server nfs-common rpcbind

Clone the Crabgrass repository or your own fork (cd to your development folder first)
-----------------------

    git clone --depth 1 git@0xacab.org:riseuplabs/crabgrass.git
    cd crabgrass/

Add optional environment variables to the end of your `~/.bashrc` file:
-----------------------

    export CRABGRASS_MYSQL_PASS='password' # MySQL password for the `root` user in VM. Default is `password`.
    export CRABGRASS_MEMORY=2048 # The maximum amount of RAM allocated for VM. Default is 2048 MB.
    export CRABGRASS_CPU_COUNT=2 # The amount of CPU's accessible for VM. Default is 2 if you have total 4 or more, otherwise 1.

Save the file and source it:

    source ~/.bashrc

Run automated provisioning
-----------------------

    vagrant up

At first it would take some time to download basic box and run provisioning scripts (depends on your Internet
connection speed and computer power) but each next time this step would take just a few seconds.

NOTE: Your would be promted to enter your system password in order to establish NFS connection.

Typical workflow
---------------------

- CD to the project directory

    `cd crabgrass/`

- Run Vagrant box

    `vagrant up`

- SSH to box

    `vagrant ssh`

- Run the server inside the box

    `cd /vagrant/`

    `BOOST=1 bundle exec rails server thin`

The application would be available in local browser at usual address `http://0.0.0.0:3000`.
ThinkingSphinx would run each session, so you no need to start it manually.

You can edit the code locally or inside a box (it synchronized automatically).

- Run the tests:

    `rake`

- Exit from the box and stop the VM when you are done

    `exit`

    `vagrant halt`


