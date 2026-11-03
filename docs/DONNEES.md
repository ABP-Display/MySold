# Données persistantes et sauvegardes

## Stockage créé par Docker Compose

Les volumes sont déclarés directement dans `compose.yaml` :

```text
MySold/
  .env                       configuration privée de son instance
  data/
    postgres/                base PostgreSQL 17 complète
    backups/                 exports de la base
    keys/master.key          clé maître AES privée (indispensable à la restauration)
```

`docker compose up -d --build` crée les dossiers et initialise une nouvelle
instance à partir du `.env` préparé par l’administrateur. Aucun script
d’installation, sauvegarde ou migration n’est requis. Le mot de passe technique
est choisi dans `.env`, avec le nom de base et l’utilisateur. Il n’est pas généré
automatiquement. La clé de chiffrement est, elle, générée aléatoirement au
premier démarrage par le service `keys`, puis conservée sans modification.

Le fichier `.env` et les exports doivent rester privés ; PostgreSQL gère les
droits de son propre dossier. Sur Linux, utiliser `sudo` pour copier ces fichiers en conservant leurs
propriétaires et permissions. `data/` et `.env` sont ignorés par Git, restent
hors des images et ne sont pas servis par Nginx.

Conserver le dossier **entier** et le fichier `.env` lors d’un transfert.
Une reconstruction Docker ne supprime pas ces dossiers. Les anciens volumes
Docker nommés ne sont ni importés ni supprimés automatiquement : cette
configuration utilise uniquement `data/postgres`.

## Sauvegarder sans arrêter le site

Depuis le dossier MySold, avec PostgreSQL démarré :

```sh
docker compose exec db sh -ec 'umask 077; pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc -f "/backups/mysold-$(date -u +%Y%m%dT%H%M%SZ).dump"'
```

Le fichier est créé directement dans `data/backups` grâce au volume Compose.
Vérifier que la commande réussit avant de conserver son export. Une commande
interrompue peut laisser un fichier incomplet. Pour contrôler un fichier, en
remplaçant son nom par celui créé :

```sh
docker compose exec db pg_restore --list /backups/mysold-20261025T100000Z.dump
```

**Sauvegarder aussi la clé de l’instance**. Le dump PostgreSQL contient les
clés utilisateur enveloppées, mais pas la clé maître permettant de les ouvrir.
Sur Linux, avant de déplacer la sauvegarde vers un emplacement privé :

```sh
sudo tar --numeric-owner -czf ../mysold-keys.tar.gz data/keys
sudo chmod 600 ../mysold-keys.tar.gz
```

Conserver cette archive dans un stockage privé, séparé des dumps si possible,
et l’associer clairement à cette instance. La clé reste identique lors des
reconstructions et des changements de mot de passe. **Sans la clé d’origine,
les données chiffrées et secrets 2AF sont irrécupérables.** Ne jamais publier
ou copier la clé dans `.env.example`, Git ou un export CSV.

Copier les sauvegardes hors du serveur dans un emplacement privé. Les dumps
contiennent des données financières et secrets MFA chiffrés, ainsi que des
métadonnées, adresses e-mail, mots de passe hachés et sessions. Un export CSV de l’application ne remplace pas cette
sauvegarde PostgreSQL. La rétention des exports est gérée par l’administrateur.

## Copier une instance sur un autre serveur

La copie physique nécessite une base arrêtée proprement, la même version
majeure PostgreSQL, une architecture compatible et des permissions conservées,
comme indiqué dans la [documentation PostgreSQL](https://www.postgresql.org/docs/17/backup-file.html).

Sur le serveur source, depuis MySold :

```sh
docker compose stop --timeout 120
sudo tar --numeric-owner -czf ../mysold-data.tar.gz data .env
sudo chmod 600 ../mysold-data.tar.gz
```

Transférer l’archive par un canal privé : elle contient aussi le `.env` avec
le mot de passe PostgreSQL. La copie physique doit être faite
pendant que les services sont arrêtés, jamais pendant leurs écritures.

Sur une nouvelle copie du dépôt **sans données existantes**, extraire l’archive :

```sh
sudo tar --numeric-owner -xzf ../mysold-data.tar.gz
```

Conserver les identifiants PostgreSQL du `.env` extrait et adapter le domaine et `COOKIE_SECURE`
si l’adresse du site change. Démarrer normalement :

```sh
docker compose up -d --build
```

Ne pas extraire une archive par-dessus une instance déjà remplie. Vérifier les
comptes et montants sur la destination avant de retirer l’instance source.

## Restaurer un export sur une nouvelle instance

L’export logique évite de recopier le format physique du cluster. Sur une
nouvelle copie du dépôt, copier `.env.example` en `.env`, renseigner ses valeurs,
puis restaurer **le dossier `data/keys` de l’instance source avant tout lancement
de `keys` ou `api`** :

```sh
sudo tar --numeric-owner -xzf ../mysold-keys.tar.gz
```

Utiliser une archive de confiance ; ne jamais extraire par-dessus une instance
existante. Démarrer uniquement la base avant que l’API ne crée les tables :

```sh
docker compose up -d --wait db
```

Copier son export de confiance dans `data/backups`, puis vérifier que la base ne
contient aucune table applicative :

```sh
docker compose exec db sh -ec 'psql -X -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "\\dt public.*"'
```

Si des tables existent déjà, utiliser une autre instance vide. Restaurer ensuite,
en remplaçant le nom du fichier :

```sh
docker compose exec db sh -ec 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges --no-tablespaces --exit-on-error --single-transaction /backups/mysold-20261025T100000Z.dump'
docker compose up -d --build
```

La restauration est transactionnelle et ne contient aucune commande `--clean`
supprimant les données existantes. Le mot de passe technique de la nouvelle instance
peut être différent ; les mots de passe des comptes et les paramètres MFA sont
restaurés avec les tables et la clé maître originale. Un export ancien,
antérieur au chiffrement, sera chiffré au premier démarrage ; pour un dump
chiffré, une nouvelle clé ne fonctionne pas.

Le [guide d’installation](INSTALLATION.md) présente le domaine et les mises à jour.

## Anciennes copies en clair

La migration chiffre les lignes applicatives et les anciens caches annuels
retirés, sans recalcul annuel ni suppression de transactions. Elle n’efface pas
rétroactivement les anciens dumps, pages PostgreSQL obsolètes, WAL ou copies
physiques. Prévoir une politique de rétention privée pour ces copies et du
chiffrement de disque/volume si la protection des supports est nécessaire.
Les exports CSV/PDF sont volontairement lisibles : les conserver en lieu sûr.
