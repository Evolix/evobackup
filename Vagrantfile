# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::DEFAULT_SERVER_URL.replace('https://vagrantcloud.com')

# Load ~/.VagrantFile if exist, permit local config provider
vagrantfile = File.join("#{Dir.home}", '.VagrantFile')
load File.expand_path(vagrantfile) if File.exists?(vagrantfile)

Vagrant.configure('2') do |config|
  config.vm.synced_folder "./vagrant_share/", "/vagrant", disabled: true

  config.vm.provider :libvirt do |libvirt|
    libvirt.storage :file, :size => '10G', :device => 'vdb'
  end

  config.vm.define :jessie do |node|
    node.vm.hostname = "bkctld-jessie"
    node.vm.box = "debian/jessie64"
  end

  config.vm.define :stretch do |node|
    node.vm.hostname = "bkctld-stretch"
    node.vm.box = "debian/stretch64"
  end

  config.vm.provision "copy", type: "file" do |f|
    f.source = "./"
    f.destination = "~/bkctld/"
   end

  config.vm.provision "deps", type: "shell" do |s|
    s.inline = "DEBIAN_FRONTEND=noninteractive apt-get -yq install openssh-server btrfs-tools rsync lsb-base coreutils sed dash mount openssh-sftp-server libc6 bash-completion"
  end

  $install = <<SCRIPT
ln -fs /home/vagrant/bkctld/bkctld /usr/sbin/bkctld
ln -fs /home/vagrant/bkctld/tpl /usr/share/bkctld
ln -fs /home/vagrant/bkctld/bash_completion /usr/share/bash-completion/completions/bkctld
ln -fs /home/vagrant/bkctld/bkctld.conf /etc/default/bkctld
SCRIPT

  config.vm.provision "install", type: "shell" do |s|
    s.inline = $install
  end

  $part = <<SCRIPT
lsof|awk '/backup/ { print $2 }'| xargs --no-run-if-empty kill -9
grep -q /backup /proc/mounts && umount -R /backup
mkfs.btrfs -f /dev/vdb
mkdir -p /backup
mount /dev/vdb /backup
SCRIPT

  config.vm.provision "part", type: "shell" do |s|
    s.inline = $part
  end

  $bkctld = <<SCRIPT
rm -f /root/bkctld.key* && ssh-keygen -t rsa -N "" -f /root/bkctld.key -q
bkctld init test
bkctld key test /root/bkctld.key.pub
bkctld start test
ssh -p 2223 -i /root/bkctld.key -oStrictHostKeyChecking=no root@127.0.0.1 lastlog -u root
SCRIPT

  config.vm.provision "bkctld", type: "shell" do |s|
    s.inline = $bkctld
  end
end
