# -*- mode: ruby -*-
# vi: set ft=ruby :

# Load ~/.VagrantFile if exist, permit local config provider
vagrantfile = File.join("#{Dir.home}", '.VagrantFile')
load File.expand_path(vagrantfile) if File.exists?(vagrantfile)

Vagrant.configure('2') do |config|
  config.vm.synced_folder "./", "/vagrant", type: "rsync", rsync__exclude: [ '.vagrant', '.git' ]
  config.ssh.shell="/bin/sh"

  config.vm.provider :libvirt do |libvirt|
    libvirt.storage :file, :size => '10G', :device => 'vdb'
  end

  $install = <<SCRIPT
ln -fs /vagrant/bkctld /usr/sbin/bkctld
ln -fs /vagrant/lib /usr/lib/bkctld
ln -fs /vagrant/tpl /usr/share/bkctld
ln -fs /vagrant/bash_completion /usr/share/bash-completion/completions/bkctld
ln -fs /vagrant/bkctld.conf /etc/default/bkctld
ln -fs /vagrant/bkctld.service /etc/systemd/system/bkctld.service && systemctl daemon-reload
mkdir -p /usr/lib/nagios/plugins/
SCRIPT

  $deps = <<SCRIPT
DEBIAN_FRONTEND=noninteractive apt-get -yq install openssh-server btrfs-tools rsync lsb-base coreutils sed dash mount openssh-sftp-server libc6 bash-completion duc-nox cryptsetup bats
SCRIPT

  $pre_part = <<SCRIPT
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    sed -i -e 's/# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen && \
    echo 'LANG="fr_FR.UTF-8"'>/etc/default/locale && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=fr_FR.UTF-8
lsof | awk '/backup/ { print $2 }' | xargs --no-run-if-empty kill -9
grep -q /backup /proc/mounts && umount -R /backup
exit 0
SCRIPT

  $post_part = <<SCRIPT
mkdir -p /backup
mount /dev/vdb /backup
SCRIPT

  nodes = [
    { :version => "stretch", :fs => "btrfs" },
    { :version => "stretch", :fs => "ext4" }
  ]

  nodes.each do |i|
    config.vm.define "#{i[:version]}-#{i[:fs]}" do |node|
      node.vm.hostname = "bkctld-#{i[:version]}-#{i[:fs]}"
      node.vm.box = "debian/#{i[:version]}64"
      config.vm.provision "deps", type: "shell", :inline => $deps
      config.vm.provision "install", type: "shell", :inline => $install
      config.vm.provision "pre_part", type: "shell", :inline => $pre_part
      config.vm.provision "part", type: "shell", :inline => "mkfs.btrfs -f /dev/vdb" if "#{i[:fs]}" == "btrfs"
      config.vm.provision "part", type: "shell", :inline => "mkfs.ext4 -q -F /dev/vdb" if "#{i[:fs]}" == "ext4"
      config.vm.provision "post_part", type: "shell", :inline => $post_part
      config.vm.provision "test", type: "shell", :inline => "bats /vagrant/test/*.bats"
    end
  end

end
