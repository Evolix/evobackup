Présentation d'EvoBackup
===

**EvoBackup** est un ensemble de scripts permettant de mettre en place
un service de backups gérant les sauvegardes de plusieurs machines.
Le principe est d'installer des prisons/chroot contenant un service
SSH écoutant sur un port différent dans chaque prison. Chaque serveur
peut ainsi envoyer ses données quotidiennement en "root" via rsync
dans sa propre prison. Les prisons sont ensuite copiées en dehors des
prisons (donc inaccessible par les serveurs) de façon incrémentale
grâce à des "hard links". On peut ainsi conserver des dizaines de
sauvegardes de chaque serveur de façon sécurisé et avec peu de place.

                                      **************************
    Serveur 1 ------SSH/rsync ------->* tcp/2222  Serveur      *
                                      *           de           *
    Serveur 2 ------SSH/rsync ------->* tcp/2223  Sauvegardes  *
                                      **************************

Cette technique de sauvegarde s'appuient sur des technologies
standards. Elle est utilisée depuis plusieurs années par Evolix
pour sauvegarder chaque jour des centaines de serveurs représentant
plusieurs To de données incrémentales.

Evobackup a été testé pour les serveurs sous Debian (Wheezy/Jessie).
Cela peut fonctionner pour d'autres distributions tel Ubuntu.
La documentation se concentre sur une mise en place pour Debian Jessie.

> **Logiciels nécessaires :**
> - OpenSSH
> - Rsync (le daemon rsync n'est pas nécessaire)
> - Le paquet makedev (plus nécessaire depuis Squeeze)
> - Commande "mail" (ou un équivalent) capable d'envoyer
des messages à l'extérieur.

Un volume d'une taille importante doit être monté sur /backup
Pour des raisons de sécurité on pourra chiffrer ce volume.
On créera ensuite les répertoires suivants :

- /backup/jails  : pour les prisons
- /backup/incs   : pour les copies incrémentales des prisons
- /etc/evobackup : config des fréquences des copies incrémentales

On peut sauvegarder différents systèmes : Linux, BSD, Windows, MacOSX.
L'un des seuls réels prérequis est d'avoir rsync.

Installation EvoBackup côté serveur
===

On récupère les sources via https://forge.evolix.org/projects/evobackup/repository et on mets en place les scripts nécessaires.

```
# git clone https://forge.evolix.org/evobackup.git
# cd evobackup
# mkdir -m750 /etc/evobackup
# install -v -m700 evobackup /etc/init.d/
# cd /etc/init.d/ && insserv evobackup
```

− Mettre en place les scripts evobackup-inc.sh et evobackup-rm.sh dans /usr/share/scripts
``` 
# install -v -m 700 evobackup-{rm,inc}.sh /usr/share/scripts/
```
− Activer la crontab suivante (ajuster éventuellement les heures) :
```
29 10 * * * pkill evobackup-rm.sh && echo "Kill evobackup-rm.sh done" | mail -s "[warn] EvoBackup - purge incs interrupted" root 
30 10 * * * /usr/share/scripts/evobackup-inc.sh && /usr/share/scripts/evobackup-rm.sh
```
> **Notes :**
> - Si l'on veut plusieurs backups dans la journée (1 par heure maximum),
  on pourra lancer `/usr/share/scripts/evobackup-inc.sh` à plusieurs reprises…
  Ce qui fonctionnera sous réserve qu'entre temps les données ont bien changés !
> - Si l'on ne veut **jamais** supprimer les backups incrémentaux, on pourra se contenter
  de ne jamais lancer le script `evobackup-rm.sh`.

  Si le noyau du serveur est patché avec *GRSEC*, on évitera pas mal
  de warnings en positionnant les paramètres Sysctl suivants :
```
# sysctl kernel.grsecurity.chroot_deny_chmod=0
# sysctl kernel.grsecurity.chroot_deny_mknod=0
```
  --- **À vérifier** --- Plus nécessaire avec un noyau récent a priori.

Créer une prison
---

  − Exporter la variable `$JAIL` avec le nom d'hôte de la machine a sauvegarder :
    
    # export JAIL=<nom d'hote>

  − Se placer dans le répertoire racine de EvoBackup (attention, ne pas déplacer le script `chroot-ssh` car
  il a besoin du répertoire etc/ !) puis exécuter :
    
    # bash chroot-ssh.sh -n /backup/jails/$JAIL -i <ip> -p <port> -k <pub-key-path>

> **Notes :**
> - Ignorer une éventuelle erreur avec `ld-linux-x86-64.so.2` (32bits) ou `ld-linux.so.2` (64bits).
> - `-i <ip>` et `-p <port>` sont optionnels, vous pouvez ajuster `/backup/jails/$JAIL/etc/ssh/sshd_config`.
> - Si une prison a déjà été crée, `-p guess` vous permettra de deviner le prochain port disponible.
> - `-k <pub-key-path>` est optionnel, vous pouvez ajouter la clé publique du client dans le fichier
`/backup/jails/$JAIL/root/.ssh/authorized_keys` déjà existant.

− Lancer la prison :
```
# mount -t proc proc-chroot /backup/jails/$JAIL/proc/
# mount -t devtmpfs udev /backup/jails/$JAIL/dev/
# mount -t devpts devpts /backup/jails/$JAIL/dev/pts
# chroot /backup/jails/$JAIL /usr/sbin/sshd > /dev/null
```

− Vérifier que tout est OK :

    # /etc/init.d/evobackup reload

− Gestion des sauvegardes incrémentales :

Pour activer les gestions des copies incrémentales,
créer le fichier `/etc/evobackup/$JAIL` contenant par
exemple :

    +%Y-%m-%d.-0day
    +%Y-%m-%d.-1day
    +%Y-%m-%d.-2day
    +%Y-%m-%d.-3day
    +%Y-%m-01.-0month
    +%Y-%m-01.-1month

> **Quelques explications sur cette syntaxe particulière.**
> - Par exemple, la ligne ci-dessous signifie "garder la sauvegarde du
jour actuel" (à toujours mettre sur la première ligne a priori) :
> > `+%Y-%m-%d.-0day`
> - La ligne ci-dessous signifie "garder la sauvegarde d'hier" :
> > `+%Y-%m-%d.-1day`
> - La ligne ci-dessous signifie "garder la sauvegarde du 1er jour du
mois courant" :
> > `+%Y-%m-01.-0month`
>- Toujours le même principe, on peut garder celle du 1er jours du
mois dernier :
> > `+%Y-%m-01.-1month`

Et bien sûr, on peut garder aussi le 15e jour (pour avoir une sauvegarde
toutes les 15 jours, le 1er janvier de chaque année, etc.)

Attention, la création de ce fichier est **obligatoire** pour activer
les copies incrémentales. Si l'on veut garder des copies *advitam aeternam*
sans jamais les supprimer, on se contentera de ne pas lancer le script
`evobackup-rm.sh`.

− Copier une prison sur un second serveur :

Dans le cas où l'on dispose de plusieurs serveurs de sauvegarde configurés en
mode nœuds, il est recommandé de créer la prison sur un nœud puis la copier sur l'autre nœud.
On utilisera rsync pour faire ceci.
```
# rsync -av --exclude='var/backup/**' --exclude='proc/**' --exclude='dev/**' \
    /backup/jails/$JAIL/ ${AutreNœud}:/backup/jails/$JAIL/
# rsync -av /etc/evobackup/$JAIL ${AutreNœud}:/etc/evobackup/
```
Ainsi le second nœud aura exactement la même prison (et même empreinte SSH).

Mise-à-jour du serveur de sauvegardes
---

En cas d'une mise-à-jour d'un paquet lié à SSH ou rsync côté
serveur de sauvegardes, on mettra à jour les prisons ainsi :
```
# ./chroot-ssh.sh -n updateall
# /etc/init.d/evobackup restart
```

Installation EvoBackup côté client
===

− On récupère les sources via https://forge.evolix.org/projects/evobackup/repository
```
# git clone https://forge.evolix.org/evobackup.git
# cd evobackup
```

− Générer une clé SSH pour l'utilisateur "root" :

    # ssh-keygen
 
> **Notes :**
> - Ne pas la protéger par une passphrase, sauf si un humain
va l'entrer manuellement à chaque sauvegarde effectuée.
> - La clé générée doit être de type RSA et non DSA !!

> **Notes pour les machines sous Windows :**
> - Téléchargez et installer CygWin : http://cygwin.com/setup-x86.exe
> - Choisissez le mirroir http://mirrors.kernel.org
 choisissez les paquets "rsync" et "openssh" grâce à la recherche,
ils sont dans la catégorie "Net", vous devez les cocher.
> - Ouvrez CygWin. Dans le terminal, tapez : `ssh-keygen.exe`.
> - La clé générée se trouve dans `C:\cygwin\home\USER\.ssh\`.

− Envoyer le fichier `id_rsa.pub` au responsable du serveur de
   sauvegarde, ainsi que l'adresse IP de la machine.
   Ou bien reportez-vous à la création d'une prison sur le serveur de sauvegarde.

− Éditer le script de sauvegarde `zzz_evobackup`.
> - `SSH_PORT` Port de la prison SSH correspondante ;
> - `SYSTEME` Linux ou BSD ;
> - `MAIL` Adresse e-mail pour les rapports ;
> - `NODE` Technique utilisée pour « calculer » sur quel nœud faire une sauvegarde.
Utilisée seulement quand on a plusieurs serveurs de sauvegardes.
La valeur par défaut permet de sauvegarder sur le nœud 0 les jours pairs, et
sur le nœud 1 les jours impairs ;
> - Dé-commenter / Ajuster / Ajouter la partie qui sauvegarde les applicatifs MySQL / LDAP /  … ;
> - Ajouter ou enlever des exclusions avec `--exclude`.
`$REP` contient les répertoires systèmes ;
> - `root@node$NODE.backup.example.com:/var/backup/` Indiquer l'adresse de votre
serveur de backup.

− Ajouter à la crontab le fichier `zzz_evobackup` pour Linux / BSD :

Pour une sauvegarde quotidienne (conseillé), utilisez le répertoire
`/etc/cron.daily/` (sous Linux) ou `/etc/periodic/daily` (sous FreeBSD).
```
# install -v -m700 zzz_evobackup /etc/cron.daily/
## OU
# install -v -m700 zzz_evobackup /etc/periodic/daily/
```
> **Note :**
> Pour les serveurs sous Windows, vous devrez créer une tâche planifiée avec une
commande "rsync" installé via CygWin.


− Une fois que tout en place au niveau du serveur de sauvegardes,
   on doit initier la première connexion et valider l'empreinte SSH du serveur :

    # ssh -p <port> <serveur de sauvegardes>



