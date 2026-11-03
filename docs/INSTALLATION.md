# Installer et mettre à jour MySold

## Installation rapide

Installer Git, Docker et le plugin Docker Compose v2 sur sa machine. Aucun
script de préparation ni installation de Node.js, Python ou Flutter n’est requis.

```sh
git clone https://github.com/ABP-Display/MySold.git
cd MySold
cp .env.example .env
# Modifier .env avec ses propres informations avant le lancement.
docker compose up -d --build
```

Ouvrir **http://localhost:28085**, puis créer son compte. Si Docker nécessite
les droits administrateur sur la machine, utiliser `sudo docker compose`.
Les services `db`, `api` et `web` démarrent dans l’ordre de leurs contrôles de
santé. Le premier lancement télécharge les images et construit l’application.

Le fichier `.env.example` fournit les champs commentés à renseigner. Choisir
son mot de passe `POSTGRES_PASSWORD` avant de lancer Compose : une valeur vide
est refusée. Les noms `POSTGRES_DB` et `POSTGRES_USER` sont personnalisables
avant la première initialisation. Compose crée les dossiers persistants
`data/postgres`, `data/backups`, `data/keys` et initialise les tables. Le service
ponctuel `keys` crée automatiquement une clé maître privée de 32 octets, sans
l’afficher. Aucun compte utilisateur ni mot de passe par défaut n’est créé.

## Personnaliser le fichier `.env`

La configuration se fait uniquement dans `.env`, copié depuis le modèle :

```sh
cp .env.example .env
```

Modifier `.env` avec son éditeur. Docker Compose le lit automatiquement ; il
n’est pas nécessaire de le copier depuis un Dockerfile ni de passer `--env-file`.
Le fichier doit rester privé et ne doit pas être committé dans Git. Exemple
de champs à personnaliser avant le premier démarrage :

```dotenv
POSTGRES_DB=mon_budget
POSTGRES_USER=mon_utilisateur
POSTGRES_PASSWORD='REMPLACER_PAR_UN_MOT_DE_PASSE_LONG_ET_UNIQUE'
```

Remplacer le mot de passe d’illustration par un secret personnel long et unique.
Le modèle ne fournit aucun mot de passe commun aux installations. Les quotes
simples permettent notamment de conserver littéralement les caractères `$` et `#`.

### Site public en HTTPS

Remplacer les origines du modèle par son propre domaine :

```dotenv
WEB_PORT=28085
APP_ORIGIN=https://finances.votre-domaine.fr
COOKIE_SECURE=true
```

Configurer le DNS et le certificat HTTPS de ce domaine, puis diriger son reverse
proxy vers `http://ADRESSE_DU_SERVEUR:28085`. Le proxy configure le HTTPS, tandis
que MySold écoute en HTTP sur son port publié.

Un proxy installé directement sur le serveur peut utiliser
`http://127.0.0.1:28085`. Dans un conteneur proxy, `127.0.0.1` désigne ce conteneur :
utiliser une adresse joignable du serveur, ou un réseau Docker partagé avec
`web` et la destination `http://web:8080`.

### Accès local et distant

HTTP est réservé à `localhost`, `127.0.0.1` et `[::1]` pour les installations
locales. L’accès distant par IP ou domaine exige un certificat HTTPS valide,
y compris sur le réseau local. Le client ne transmet pas de données vers une
origine HTTP distante et l’API refuse ses écritures même si elle est autorisée
dans `.env`. Pour une PWA sur téléphone, utiliser un domaine HTTPS accessible.

Le proxy doit rediriger HTTP vers HTTPS, utiliser TLS 1.2 ou 1.3 et remplacer
`X-Forwarded-Proto` par le protocole public réel (`https`). MySold ajoute alors
HSTS sur les réponses. Définir `COOKIE_SECURE=true` ; une connexion provenant
d’une origine HTTPS reçoit aussi automatiquement un cookie de session Secure.
Les certificats et le proxy ne sont pas générés par Compose.

Une origine comprend le protocole, le domaine ou l’IP et le port non standard,
sans chemin. Plusieurs origines sont séparées par des virgules ; aucun joker.
Une origine incorrecte entraîne `403 Origine refusée` lors de la connexion, de
l’inscription ou d’une écriture. `WEB_PORT` peut être modifié, en adaptant aussi
les origines HTTP et la destination du proxy.

Le port est publié sur toutes les interfaces. Chaque administrateur configure
son pare-feu, son DNS et son proxy. En production, réserver le port HTTP `28085`
au proxy avec le pare-feu. La base et l’API ne publient aucun port.

Après toute modification de `.env` :

```sh
docker compose up -d --build
```

## Mots de passe et données

| Secret | Rôle |
| --- | --- |
| `POSTGRES_PASSWORD` dans `.env` | Mot de passe technique choisi par l’administrateur pour PostgreSQL et l’API |
| Mot de passe MySold | Choisi par chaque utilisateur lors de la création du compte sur le site |
| PIN | Choisi par l’utilisateur pour verrouiller son interface |

`POSTGRES_PASSWORD` est obligatoire et n’est jamais généré automatiquement.
Les valeurs `POSTGRES_DB`, `POSTGRES_USER` et `POSTGRES_PASSWORD` sont utilisées
par PostgreSQL lors de la première initialisation et par l’API pour se connecter.

Conserver les valeurs avec la base. Modifier seulement `.env` après cette
initialisation ne renomme pas la base ni son utilisateur et ne change pas son
mot de passe PostgreSQL. Lors d’une mise à jour, conserver ces valeurs.

Les volumes sont définis directement dans `compose.yaml`. `data/` et `.env`
sont ignorés par Git et ne sont pas remplacés par un `git pull` ou une
reconstruction des images. Le [guide des données](DONNEES.md) explique les
sauvegardes et la copie vers une autre machine.

## Mettre à jour

Depuis le dossier MySold :

```sh
git pull --ff-only
docker compose up -d --build
```

Conserver `data/` et `.env`. Aucun script de migration n’est à lancer.
La mise à jour du schéma est effectuée automatiquement au démarrage de l’API.
Lors du premier passage au chiffrement, les documents existants et secrets 2AF
sont convertis par lots avant l’ouverture de l’API ; une interruption reprend
au prochain lancement. Faire une sauvegarde préalable, puis sauvegarder aussi
`data/keys` dès cette première mise à jour. Une mauvaise clé bloque le démarrage,
sans réinitialiser les données. Ne jamais supprimer ou remplacer ce dossier.
La PWA propose ensuite sa mise à jour lorsqu’un nouveau build Web est installé.

## Vérifier et administrer

| Action | Commande |
| --- | --- |
| Démarrer, reconstruire ou appliquer `.env` | `docker compose up -d --build` |
| Vérifier la configuration sans afficher de secrets | `docker compose config --quiet` |
| État des services | `docker compose ps` |
| Derniers logs | `docker compose logs --tail=100 db api web` |
| Arrêter en conservant les données | `docker compose stop --timeout 120` |
| Reprendre après un arrêt | `docker compose up -d` |
| Réinitialiser un mot de passe de compte | `docker compose exec api python manage.py reset-password utilisateur@example.fr` |

Les lignes `GET / ... 200 ... Wget` toutes les 15 secondes sont les contrôles de
santé Web et sont normales. Si l’affichage du site fonctionne mais pas la
connexion, vérifier `APP_ORIGIN`. Une erreur de proxy `502` demande de vérifier
la destination, le port et l’état des services.

Le frontend est construit par GitHub Actions et téléchargé automatiquement par
le Dockerfile avec vérification d’intégrité. Si la release correspondant aux
sources n’est pas encore disponible, attendre la réussite du workflow **Web
release**, puis relancer la construction. Le serveur ne compile pas Flutter.
Le [README](../README.md) décrit aussi la compilation depuis les sources et les forks.

Le [guide de sécurité](SECURITE.md) décrit le chiffrement, ses limites et la récupération.
