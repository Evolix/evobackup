# Munin plugins for bkctld

Plugins can be installed in /etc/munin/plugins/bkctld_incs (as executables)
and be run as root :

~~~
# cat /etc/munin/plugin-conf.d/bkctld
[bkctld_*]
    user root
~~~

Don't forget to `systemctl restart munin-node`


## Manual/Quick Deploy

~~~
wget https://gitea.evolix.org/evolix/evobackup/raw/branch/master/server/misc/munin-plugin/bkctld_incs -O /etc/munin/plugins/bkctld_incs
wget https://gitea.evolix.org/evolix/evobackup/raw/branch/master/server/misc/munin-plugin/bkctld_jails -O /etc/munin/plugins/bkctld_jails
wget https://gitea.evolix.org/evolix/evobackup/raw/branch/master/server/misc/munin-plugin/bkctld_ops -O /etc/munin/plugins/bkctld_ops
wget https://gitea.evolix.org/evolix/evobackup/raw/branch/master/server/misc/munin-plugin/bkctld_rsyncs -O /etc/munin/plugins/bkctld_rsyncs
chmod 755 /etc/munin/plugins/bkctld_*

echo "[bkctld_*]
    user root
" > /etc/munin/plugin-conf.d/bkctld

systemctl restart munin-node
~~~
