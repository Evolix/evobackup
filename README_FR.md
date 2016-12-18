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
# ./install.sh
```

> **Notes :**
> - Si l'on veut plusieurs backups dans la journée (1 par heure maximum),
  on pourra lancer `bkctl inc` à plusieurs reprises…
  Ce qui fonctionnera sous réserve qu'entre temps les données ont bien changés !
> - Si l'on ne veut **jamais** supprimer les backups incrémentaux, on pourra se contenter
  de ne jamais lancer la coomande `bkctl rm`.

  Si le noyau du serveur est patché avec *GRSEC*, on évitera pas mal
  de warnings en positionnant les paramètres Sysctl suivants :
```
# sysctl kernel.grsecurity.chroot_deny_chmod=0
# sysctl kernel.grsecurity.chroot_deny_mknod=0
```
  --- **À vérifier** --- Plus nécessaire avec un noyau récent a priori.

Créer une prison
---
    Cr�er la prison :

    # bkctl init <hostname>

    Changer le port d'�coute (defaut: 2222) :

    # bkctl port <hostname> <port>

    Autoriser une cl� publique :

    # bkctl key <hostname> <pubkeyfile>

    Lancer la prison :

    # bkctl start <hostname>

    V�rifier que tout est OK :

    # bkctl status <hostname>

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
`bkctl rm`.

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



