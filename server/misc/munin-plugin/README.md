# Munin plugins for bkctld

This is a work-in-progress.

Plugins can be installed in /etc/munin/plugins/bkctld_incs (as executables)
and be run as root :

~~~
# cat /etc/munin/plugin-conf.d/bkctld
[bkctld_*]
    user root
~~~

Don't forget to `systemctl restart munin-node`