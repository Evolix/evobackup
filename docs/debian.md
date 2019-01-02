# Debian Package

The **bkctld** package can be built from the **debian** branch of
this git repository with git-buildpackage and sbuild.

## Dependencies

Install Debian dependencies :

~~~
apt install git-buildpackage sbuild
~~~

Add your user to sbuild :

~~~
sbuild-adduser <username>
~~~

*You must logout and re-login or use `newgrp sbuild` in your current shell*

You need a schroot definition in */etc/schroot/schroot.conf*, eg :

~~~
[sid]
description=Debian sid (unstable)
directory=/srv/chroot/sid
groups=root,sbuild
root-groups=root,sbuild
aliases=unstable,default
~~~

Build the sbuild chroot :

~~~
sbuild-createchroot --include=eatmydata,ccache,gnupg unstable /srv/chroot/sid http://deb.debian.org/debian
~~~

## Build

You must be in the **debian** branch :

~~~
git checkout debian
~~~

Launch git-buildpackage :

~~~
gbp buildpackage
~~~
