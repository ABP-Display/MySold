# Données persistantes, sauvegardes et migration

## Où sont les données ?

Une nouvelle installation utilise `POSTGRES_STORAGE=./data/postgres`, renseigné
dans le `.env` créé par `sh scripts/setup.sh` :

```text
MySold/
  .env                     configuration active, privée
  data/
    postgres/              cluster PostgreSQL 17 complet
    backups/               exports logiques terminés, au format .dump
    config/instance.env    copie privée de .env, actualisée par les outils
```

Le script d’installation crée `data/backups` et `data/config`. Docker crée
`data/postgres` lors du premier **démarrage** ; la construction d’une image seule
ne crée pas une base sur l’hôte. Les mises à jour et reconstructions d’images
conservent ce stockage.

La base contient les comptes, mots de passe hachés, documents financiers,
sessions, paramètres et informations MFA. Les exports CSV de l’application ne
remplacent pas une sauvegarde PostgreSQL complète.

`data/` est exclu de Git. Il n’est pas inclus dans les images de l’API ou du site,
ni accessible par Nginx. Les exports et la copie de configuration sont privés
(fichiers à 600). Le dossier PostgreSQL appartient à l’utilisateur technique de
l’image : utiliser `sudo` pour le copier en conservant ses permissions.

`data/config/instance.env` est une copie de secours, **pas la configuration active**.
Elle est actualisée par `setup.sh`, puis à chaque sauvegarde, migration ou
restauration réussie. Modifier `.env` à la racine pour configurer l’instance.

## Instance existante utilisant l’ancien volume Docker

**Un `git pull` ne déplace pas automatiquement les données.** Sans la variable
`POSTGRES_STORAGE` dans son ancien `.env`, Compose conserve le volume Docker
`postgres_data`. Une mise à jour normale continue donc à ouvrir la même base.

Pour passer une seule fois au dossier `data/postgres`, ne pas ajouter la variable
à la main et ne pas recopier `.env.example`. Depuis le dépôt existant :

```sh
cd ~/MySold
sudo git pull --ff-only
sudo sh scripts/data.sh migrate
sudo docker compose --env-file .env up -d --build
sudo docker compose --env-file .env ps
```

Utiliser `git pull` sans sudo si le dépôt appartient à son compte utilisateur.
Pour un projet utilisant un `COMPOSE_PROJECT_NAME` personnalisé, conserver la
même valeur pour toutes les commandes ; l’outil identifie le volume réellement
monté par le service `db`, sans supposer son nom.

La commande `migrate` :

1. Refuse une destination déjà remplie ou une copie précédente incomplète.
2. Identifie le volume du conteneur PostgreSQL existant.
3. Arrête les services proprement, avec un délai maximal de 120 secondes.
4. Vérifie l’arrêt du cluster et la version majeure, puis copie la source montée
   en lecture seule dans `data/postgres.migrating`.
5. Compare la copie à la source et la renomme en `data/postgres`.
6. Ajoute `POSTGRES_STORAGE=./data/postgres` dans `.env` après réussite, sans
   changer le secret, le domaine ou les autres réglages.

Prévoir une interruption pendant cette commande et le redémarrage qui suit.
**L’ancien volume est conservé et n’est jamais supprimé par l’outil.** Ne pas
utiliser une commande supprimant les volumes pour effectuer cette migration.

En cas d’échec de copie, `.env` reste sur l’ancien stockage. Le dossier temporaire
peut rester présent pour inspection ; ne pas le confondre avec une copie validée.
L’outil ne l’efface pas et refuse de le réutiliser automatiquement. Une source
encore active, un arrêt incomplet, des WAL ou tablespaces externes imposent de
corriger la situation ou d’utiliser un export logique.

Après réussite, utiliser seulement les commandes ordinaires de mise à jour ;
ne pas relancer `migrate` sur une destination déjà remplie.

## Export logique sans arrêter le site

Depuis le dossier MySold, avec la base démarrée :

```sh
sudo sh scripts/data.sh backup
```

Le nom du fichier terminé est affiché, par exemple
`data/backups/mysold-20261025T100000Z.ABCDEF.dump` (heure UTC).
L’outil utilise `pg_dump`, vérifie la lisibilité de l’archive et ne publie le
fichier `.dump` qu’après réussite. Un export qui échoue n’est pas conservé comme
sauvegarde valide. Il actualise aussi `data/config/instance.env`.

Copier les sauvegardes hors du serveur dans un emplacement privé et protégé.
Elles contiennent notamment les secrets MFA ; ne jamais les publier dans Git,
une release GitHub ou un répertoire Web. Tester une restauration sur une
instance séparée avant de compter sur une sauvegarde.

## Copier tout le dossier vers un autre serveur

La copie brute du cluster nécessite un **arrêt propre de PostgreSQL**, l’ensemble
du cluster, des permissions conservées, une architecture compatible et la même
version majeure PostgreSQL. Ces conditions sont détaillées dans la
[documentation PostgreSQL](https://www.postgresql.org/docs/17/backup-file.html).
Pour changer de plateforme ou de format de stockage, préférer l’export logique.

Cette procédure suppose que l’instance utilise déjà `data/postgres` ; effectuer
d’abord la migration ci-dessus si elle utilise encore un volume nommé.

Sur le serveur source, actualiser l’export et la configuration, puis arrêter les
services avant de copier quoi que ce soit :

```sh
cd ~/MySold
sudo sh scripts/data.sh backup
sudo docker compose --env-file .env stop --timeout 120
sudo sh -c '
set -eu
test -f data/postgres/PG_VERSION
test ! -e data/postgres/postmaster.pid
umask 077
archive="../mysold-data-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"
tar --numeric-owner -czf "$archive" data
chown "${SUDO_UID:-0}:${SUDO_GID:-0}" "$archive"
printf "Archive : %s\n" "$archive"
'
```

L’archive privée est créée dans le dossier parent, hors de `data/` et du dépôt.
Elle contient la base, les exports et la copie de configuration. Seul le compte
qui a lancé `sudo` peut la lire (mode 600), ce qui permet un transfert SSH/SCP
avec ce compte. La commande refuse d’archiver un dossier sans base ou avec un
fichier indiquant un serveur encore actif. Transférer cette archive par un canal
privé vers le serveur cible.

Sur une **nouvelle copie du dépôt sans `.env` ni `data/postgres` existants**,
extraire l’archive depuis le dossier MySold, en remplaçant le nom d’exemple :

```sh
sudo sh -c 'set -eu; test ! -e .env; test ! -e data/postgres; tar --numeric-owner -xzf "$1"' sh ../mysold-data-20261025T100000Z.tar.gz
sudo cp -n data/config/instance.env .env
sudo chmod 600 .env
sudo nano .env
```

Conserver le secret PostgreSQL copié et `POSTGRES_STORAGE=./data/postgres`.
Adapter `APP_ORIGIN`, `COOKIE_SECURE` et le proxy si l’adresse du site change,
puis lancer l’instance cible :

```sh
sudo docker compose --env-file .env up -d --build
sudo docker compose --env-file .env ps
```

Ne pas fusionner cette archive avec une instance déjà remplie. Vérifier les
comptes et montants sur la cible avant de retirer l’ancienne instance. Si la
migration est abandonnée, l’instance source peut être relancée avec son `up -d
--build` habituel ; éviter d’écrire simultanément sur les deux copies.

## Restaurer un export logique sur une nouvelle instance

Cette méthode recrée les données depuis le fichier `.dump` et évite de copier
le format physique du cluster. Préparer une **nouvelle instance** du dépôt :

```sh
sh scripts/setup.sh
nano .env
```

Renseigner le nouveau domaine et conserver un secret PostgreSQL fort. Le secret
de connexion de cette nouvelle base peut être différent de celui de la source.
Ne pas démarrer l’API ou le site avant de restaurer :

```sh
sudo sh scripts/data.sh restore /CHEMIN/PRIVE/mysold-sauvegarde.dump
sudo docker compose --env-file .env up -d --build
sudo docker compose --env-file .env ps
```

L’outil démarre uniquement PostgreSQL et refuse une application déjà en cours
d’exécution ou une base contenant des objets utilisateur, même si ses tables
sont vides. La restauration est transactionnelle et ne supprime pas de données
existantes. Un fichier invalide ou une erreur de restauration provoque un échec,
sans conserver une restauration partielle. Les comptes MySold, leurs mots de
passe et le MFA sont restaurés avec la base. Les tables sont restaurées dans le
stockage PostgreSQL de destination, sans reprendre d’anciens tablespaces externes.

Ne restaurer que des sauvegardes de confiance. Les sauvegardes ne sont pas
automatiquement supprimées lors d’une mise à jour ; leur rétention est à gérer
par l’administrateur.

Le [guide d’installation](INSTALLATION.md) décrit la configuration du site et
les commandes courantes. Le [README](../README.md) présente l’architecture.
