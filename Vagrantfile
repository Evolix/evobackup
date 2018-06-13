# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::DEFAULT_SERVER_URL.replace('https://vagrantcloud.com')

# Load ~/.VagrantFile if exist, permit local config provider
vagrantfile = File.join("#{Dir.home}", '.VagrantFile')
load File.expand_path(vagrantfile) if File.exists?(vagrantfile)

Vagrant.configure('2') do |config|
  config.vm.synced_folder "./", "/vagrant", type: "rsync", rsync__exclude: [ '.vagrant', '.git' ]

  config.vm.provider :libvirt do |libvirt|
    libvirt.storage :file, :size => '10G', :device => 'vdb'
  end

  $install = <<SCRIPT
ln -fs /vagrant/bkctld /usr/sbin/bkctld
ln -fs /vagrant/tpl /usr/share/bkctld
ln -fs /vagrant/bash_completion /usr/share/bash-completion/completions/bkctld
ln -fs /vagrant/bkctld.conf /etc/default/bkctld
mkdir -p /usr/lib/nagios/plugins/
SCRIPT

  $deps = <<SCRIPT
DEBIAN_FRONTEND=noninteractive apt-get -yq install openssh-server btrfs-tools rsync lsb-base coreutils sed dash mount openssh-sftp-server libc6 bash-completion duc-nox
SCRIPT

  $pre_part = <<SCRIPT
lsof|awk '/backup/ { print $2 }'| xargs --no-run-if-empty kill -9
grep -q /backup /proc/mounts && umount -R /backup
exit 0
SCRIPT

  $post_part = <<SCRIPT
mkdir -p /backup
mount /dev/vdb /backup
SCRIPT

  nodes = [
    { :version => "jessie", :fs => "btrfs" },
    { :version => "jessie", :fs => "ext4" },
    { :version => "stretch", :fs => "btrfs" },
    { :version => "stretch", :fs => "ext4" }
  ]

  nodes.each do |i|
    config.vm.define "#{i[:version]}-#{i[:fs]}" do |node|
      node.vm.hostname = "bkctld-#{i[:version]}-#{i[:fs]}"
      node.vm.box = "debian/#{i[:version]}64"
      config.vm.provision "deps", type: "shell", :inline => $deps
      if ("#{i[:version]}" == "jessie") then
        config.vm.provision "backports", type: "shell" do |s|
          s.inline = "echo 'deb http://deb.debian.org/debian jessie-backports main' > /etc/apt/sources.list.d/backports.list && apt-get update"
        end
        config.vm.provision "bats", type: "shell", :inline => "DEBIAN_FRONTEND=noninteractive apt-get -yq install -t jessie-backports bats"
      else
        config.vm.provision "bats", type: "shell", :inline => "DEBIAN_FRONTEND=noninteractive apt-get -yq install bats"
      end
      config.vm.provision "install", type: "shell", :inline => $install
      config.vm.provision "pre_part", type: "shell", :inline => $pre_part
      config.vm.provision "part", type: "shell", :inline => "mkfs.btrfs -f /dev/vdb" if "#{i[:fs]}" == "btrfs"
      config.vm.provision "part", type: "shell", :inline => "mkfs.ext4 -q -F /dev/vdb" if "#{i[:fs]}" == "ext4"
      config.vm.provision "post_part", type: "shell", :inline => $post_part
      config.vm.provision "test", type: "shell", :inline => "bats /vagrant/test/*.bats"
    end
  end

end
