# MySold

Votre budget et votre patrimoine, sur votre propre serveur.

MySold est l’édition web auto-hébergée de Sold Up. Elle reprend son interface
Flutter responsive : suivi mensuel, statistiques, vue globale, comptes,
catégories, investissements, thèmes, langues, mode discret et rapports PDF.
Elle utilise une API locale et PostgreSQL. Aucun projet Firebase, compte Google,
clé d’API bancaire ou service cloud applicatif n’est nécessaire.

Une [démonstration statique](docs/README.md) est disponible dans `docs/` : ouvrir
`docs/index.html` pour parcourir une vitrine avec des données fictives, sans API,
connexion ni conservation de données utilisateur. Ce dossier peut être publié
séparément sur GitHub Pages, sans déployer l’application Docker.

## Démarrage

Le [guide d’installation complet](docs/INSTALLATION.md) détaille les mots de
passe, le domaine, le reverse proxy, les commandes et les mises à jour.
Les étapes suivantes concernent une **nouvelle installation Ubuntu/Linux**.
Pour une instance déjà utilisée, conserver son `.env` et son stockage PostgreSQL.
Le [guide des données persistantes](docs/DONNEES.md) explique la migration et les sauvegardes.

Prérequis : Git, Docker et Docker Compose v2. Node.js, Python et Flutter ne sont
pas nécessaires sur l’hôte. Exécuter les commandes ligne par ligne, sans virgules.

### 1. Récupérer le projet

```sh
cd ~
git clone https://github.com/ABP-Display/MySold.git
cd MySold
```

Cloner sans `sudo` pour pouvoir modifier ses fichiers avec son compte Ubuntu.

### 2. Créer `.env` et le mot de passe de la base

```sh
sh scripts/setup.sh
nano .env
```

Le script crée un `.env` privé et génère automatiquement un secret aléatoire de
64 caractères pour `POSTGRES_PASSWORD`. **Conserver ce secret généré.** Ne pas
le remplacer par un mot de passe d’exemple ni publier le fichier `.env`.
Le script conserve un fichier existant et refuse une valeur vide ou restée à
`REPLACE_WITH_A_RANDOM_PASSWORD`. Il prépare aussi `data/backups` et `data/config`
et y garde une copie privée de la configuration. Le démarrage Docker crée
`data/postgres` pour une nouvelle installation.

| Secret | À quoi sert-il ? |
| --- | --- |
| `POSTGRES_PASSWORD` dans `.env` | Connexion technique de l’API à PostgreSQL ; ce n’est pas le mot de passe pour entrer sur le site |
| Mot de passe du compte MySold | Choisi avec son e-mail lors de la création du compte sur le site |
| PIN à six chiffres | Choisi dans le parcours de création du compte pour verrouiller l’interface |

Copier seulement `.env.example` en `.env` ne suffit pas : il faut remplacer son
secret d’exemple **avant le premier démarrage**. Si la base a déjà été créée,
suivre la [procédure de changement du secret existant](docs/INSTALLATION.md#changer-le-mot-de-passe-dune-base-existante)
plutôt que de modifier uniquement `.env`.

### 3. Renseigner l’adresse du site

Dans `.env`, remplacer les origines du modèle par **son propre domaine**, par exemple :

```dotenv
WEB_PORT=28085
APP_ORIGIN=https://finances.votre-domaine.fr
COOKIE_SECURE=true
```

Le domaine doit pointer vers le serveur et le reverse proxy HTTPS vers
`http://ADRESSE_DU_SERVEUR:28085`. Le [guide](docs/INSTALLATION.md#4-configurer-ladresse-du-site)
détaille le cas d’un proxy installé dans Docker.

Pour un essai HTTP directement par IP, remplacer l’adresse d’exemple ci-dessous
par l’IP réelle du serveur et ouvrir cette même adresse dans le navigateur :

```dotenv
APP_ORIGIN=http://192.0.2.10:28085
COOKIE_SECURE=false
```

`http://localhost:28085` convient uniquement depuis l’ordinateur qui héberge
Docker. Une origine comporte le protocole, le domaine ou l’IP et le port non
standard, sans chemin ni barre oblique finale. Plusieurs origines sont séparées
par des virgules. Un mauvais `APP_ORIGIN` peut bloquer la connexion avec `403`.
Le port `28085` est publié sur toutes les interfaces ; l’administrateur configure
le pare-feu, le DNS et le reverse proxy.

Dans Nano : **Ctrl+O**, **Entrée**, puis **Ctrl+X** pour enregistrer et quitter.

### 4. Vérifier et lancer les services

```sh
sh scripts/setup.sh
sudo docker compose --env-file .env config --quiet
sudo docker compose --env-file .env up -d --build
sudo docker compose --env-file .env ps
```

Le second appel au script valide le secret sans le modifier. `config --quiet`
termine sans afficher de texte lorsque Compose est valide. Les trois services
`db`, `api` et `web` doivent démarrer ; `web` peut rester quelques secondes
avec un état de santé en cours de démarrage. Pour lire les derniers logs :

```sh
sudo docker compose --env-file .env logs --tail=100 db api web
```

### 5. Créer son compte MySold

Ouvrir son domaine HTTPS ou l’IP HTTP configurée, choisir **Créer un compte**,
puis renseigner son e-mail, son mot de passe personnel et son PIN. Aucun compte
ni mot de passe de connexion par défaut n’est créé. Chaque utilisateur possède
son espace isolé. Le secret PostgreSQL de `.env` n’est pas à saisir sur cet écran.

Si le dossier a déjà été cloné avec `sudo`, utiliser `sudo sh scripts/setup.sh`
et `sudo nano .env` pour les fichiers appartenant à root.

### Construction automatique et mises à jour

Chaque modification des sources du frontend poussée sur `main` déclenche le
workflow **Web release** de GitHub Actions. Il compile Flutter depuis les sources
publiques avec `frontend/Dockerfile.source`, génère le numéro de build PWA daté,
puis publie les fichiers Web et leur empreinte dans une release publique.

Le Dockerfile utilisé par défaut calcule une empreinte des sources de la copie
locale, télécharge uniquement la release correspondante et vérifie son intégrité,
ses métadonnées et la cohérence du build PWA. Le VPS ne compile pas Flutter.
Il n’y a aucun fichier à envoyer depuis un poste Windows ni de binaire à committer
dans Git. Une copie de sources différente ne peut pas utiliser silencieusement
la release d’une autre version. Les fins de ligne Windows/Linux sont normalisées
pour le calcul de l’empreinte ; les ressources binaires restent inchangées.

Après publication réussie du workflow, la mise à jour est :

```sh
git pull --ff-only
sudo docker compose --env-file .env up -d --build
sudo docker compose ps
```

Si le dépôt appartient à root à cause d’un précédent `sudo git clone`, la
commande de récupération doit également être `sudo git pull --ff-only`.
Ne pas recréer `.env` ni supprimer le volume PostgreSQL lors d’une mise à jour.

Si la release n’est pas encore publiée, Docker indique l’URL du workflow à
attendre et arrête la construction. Il ne lance pas une compilation Flutter de
secours sur la VM et n’installe pas une ancienne release au hasard. Corriger
un éventuel échec du workflow, puis relancer la même commande Docker.

Les téléchargements publics ne nécessitent ni compte GitHub ni jeton sur le VPS.
Internet est nécessaire pendant la construction. Après installation, les données
et l’authentification sont gérées par l’API et PostgreSQL de l’instance.

### Développement et forks

La compilation complète depuis les sources reste disponible explicitement :

```sh
docker compose --env-file .env -f compose.yaml -f compose.source.yaml up -d --build
```

Ce mode utilise `FLUTTER_VERSION` (3.44.0 par défaut) et nécessite une machine
capable de compiler Flutter. Une VM de 1 Go sans swap peut saturer dès la
préparation de l’outil Flutter. Privilégier l’installation automatique par défaut
sur ces petites machines. La release correspondante est récupérée automatiquement
par Docker ; aucun envoi manuel de fichiers compilés n’est nécessaire.

Pour un fork public, activer GitHub Actions, laisser le workflow publier sa
release et définir `MYSOLD_REPOSITORY=PROPRIETAIRE/DEPOT` dans `.env`. Les sources
modifiées nécessitent leur propre release ; elles ne peuvent pas réutiliser le
build officiel. Un fork privé peut utiliser le mode de compilation depuis les
sources, sans transmettre de jeton privé à l’image d’installation.

### Dépannage

`POSTGRES_PASSWORD is missing a value` indique une configuration absente ou vide.
Exécuter `sh scripts/setup.sh` pour une installation neuve, ou restaurer le `.env`
de l’instance existante. Le script ne remplace jamais un secret déjà configuré.
Une variable seulement exportée dans le shell peut être retirée par `sudo` ;
`--env-file .env` rend l’emplacement du fichier explicite.

Le message `Bake ... buildx isn't installed` est un avertissement Docker distinct.
Si Bake est utilisé, installer le plugin Buildx adapté à son installation ; voir
la [documentation Docker pour Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

Pour examiner les ressources d’une machine, exécuter les commandes sur des
lignes séparées, sans virgules :

```sh
uname -m
free -h
df -h /
sudo journalctl -k -b -1 --no-pager | grep -Ei 'out of memory|oom|killed process|invalid opcode|segfault'
```

L’absence de journal du démarrage précédent n’exclut pas un manque de mémoire.
En mode source, le premier démarrage Flutter compile silencieusement
`flutter_tools.snapshot` après `Got dependencies` : une pause à cet endroit
ne prouve pas une incompatibilité du code de MySold.

## Architecture

```text
Navigateur / PWA
       |
       v
web : Nginx + interface Flutter
       | /api/*, même origine
       v
api : Flask + Gunicorn
       |
       v
db : PostgreSQL + dossier data/postgres (nouvelles installations)
```

- `frontend/` : copie indépendante de l’interface, limitée au web.
- `frontend/lib/data/` : client HTTP, session locale et accès aux documents.
- `frontend/lib/services/budget_service.dart` : logique de gestion financière.
- `backend/` : authentification, validation, accès SQL et commandes administrateur.
- `backend/schema.sql` : création idempotente des tables et index.
- `compose.yaml` : déploiement des trois services.

Les données financières utilisent des documents JSONB PostgreSQL rattachés à un
utilisateur, avec des collections connues (`accounts`, `categories`,
`investments`, `transactions`, `budgetAlerts`). Ce choix conserve les identifiants,
les relations et le format CSV existants. Il ne s’agit ni d’un émulateur Firebase,
ni d’une connexion cachée à Firestore. Les comptes de connexion et les sessions
sont dans des tables distinctes ; ils ne sont pas importables par CSV.

Les requêtes sont filtrées sur le serveur et paginées. Le navigateur garde un
cache en mémoire, vidé après une écriture et lors d’un changement de session.
Les écrans réagissent aux écritures de l’onglet courant. Un autre navigateur doit
recharger la page pour retrouver les changements ; cette version ne comporte pas
de synchronisation temps réel entre appareils. Les données financières ne sont
pas conservées par le service worker.

## Configuration et HTTPS

| Variable | Rôle |
| --- | --- |
| `POSTGRES_PASSWORD` | Secret de connexion de l’API à PostgreSQL |
| `POSTGRES_DB`, `POSTGRES_USER` | Nom de base et utilisateur PostgreSQL |
| `POSTGRES_STORAGE` | Nouvelles installations : `./data/postgres` ; absent sur une ancienne instance : maintien du volume Docker existant |
| `WEB_PORT` | Port HTTP local, `28085` par défaut |
| `APP_ORIGIN` | Origines autorisées pour les écritures, séparées par des virgules ; défaut : `http://localhost:28085,https://mysold.ydoxide.fr` |
| `COOKIE_SECURE` | `true` lorsque l’accès au site utilise HTTPS |
| `ALLOW_REGISTRATION` | `false` pour fermer les nouvelles inscriptions |
| `MYSOLD_REPOSITORY` | Dépôt GitHub public publiant les releases Web ; défaut `ABP-Display/MySold` |
| `FLUTTER_VERSION` | SDK du mode `compose.source.yaml` uniquement ; défaut `3.44.0` |

MySold publie le port `28085` sur toutes les interfaces. Toute machine pouvant
joindre ce port peut charger le site ; les données restent protégées par la
connexion utilisateur. Les écritures exigent une origine autorisée.
L’administrateur gère son pare-feu, son DNS et son reverse proxy.

**Chaque administrateur doit remplacer `APP_ORIGIN` par le domaine personnel de
son instance.** `mysold.ydoxide.fr` est une valeur par défaut, à remplacer si vous
hébergez MySold sur un autre domaine. Exemple pour votre propre site HTTPS :

```dotenv
APP_ORIGIN=https://finances.votre-domaine.fr
COOKIE_SECURE=true
```

Renseigner l’origine exacte utilisée dans le navigateur : protocole (`http` ou
`https`), nom de domaine ou adresse IP, et port s’il est non standard. Ne pas
ajouter de chemin ni de barre oblique finale. Plusieurs accès peuvent être
autorisés en les séparant par des virgules :

```dotenv
APP_ORIGIN=http://localhost:28085,https://finances.votre-domaine.fr
```

Pour un accès direct par IP, ajouter par exemple `http://192.168.1.20:28085`.
Si `WEB_PORT` change, adapter aussi le port de l’origine HTTP correspondante.
Une valeur vide n’autorise aucune écriture. Les jokers ne sont pas pris en charge.
Une origine absente ou non autorisée entraîne une réponse `403 Origine refusée`
sur les requêtes POST, PUT, PATCH et DELETE, notamment la connexion et
l’inscription. Les scripts qui écrivent doivent aussi envoyer l’en-tête `Origin`.
Ce contrôle ne remplace pas le pare-feu et ne configure ni le DNS ni le proxy.
Le script de configuration conserve les `.env` existants : y ajouter manuellement
`APP_ORIGIN` lors d’une mise à jour, puis recréer les conteneurs avec la commande
ci-dessous.

Pour HTTPS, diriger le proxy vers `http://ADRESSE_DU_SERVEUR:28085` et définir
`COOKIE_SECURE=true` dans `.env`. Un proxy installé directement sur le même
serveur peut utiliser `http://127.0.0.1:28085`. Dans un conteneur proxy,
`127.0.0.1` désigne ce conteneur : utiliser une adresse joignable du serveur,
ou un réseau Docker partagé avec `web` et la destination `http://web:8080`.
Le port interne reste `8080`, même si `WEB_PORT` est modifié.

La base et l’API ne publient aucun port sur l’hôte. Ne pas exposer
PostgreSQL sur Internet. Changer le mot de passe dans `.env` après initialisation
ne change pas automatiquement le mot de passe du rôle PostgreSQL existant.

Après modification de la configuration :

```sh
docker compose up -d --build
docker compose ps
docker compose logs --tail=100 api web
```

Depuis la machine du proxy, vérifier que sa destination HTTP répond, puis ouvrir
le domaine HTTPS. Une erreur `502` ou un délai d’attente nécessite de vérifier
l’adresse cible, le port, le réseau Docker et le pare-feu.

Les lignes `GET / ... 200 ... Wget` toutes les 15 secondes sont normales :
elles proviennent du contrôle de santé Docker du service `web`. Le code `200`
confirme que Nginx répond dans le conteneur ; il ne vérifie pas l’accès au domaine
depuis Internet.

## Installation mobile

MySold est une PWA : ouvrir le site HTTPS depuis le navigateur du téléphone et
utiliser « Installer l’application » ou « Ajouter à l’écran d’accueil » selon le
navigateur. Sur iOS, utiliser le menu de partage de Safari. Aucun APK n’est fourni.
`localhost` est adapté aux essais sur l’ordinateur ; un téléphone doit atteindre
un véritable nom de serveur HTTPS pour bénéficier correctement de la PWA.

La PWA conserve l’enveloppe publique du site. L’accès aux données et les
modifications nécessitent une connexion au serveur de l’instance. Les seuils
budgétaires sont enregistrés dans la base. Les notifications navigateur sont
facultatives et déclenchées lorsque l’application est ouverte ; il n’y a pas de
push externe ni de tâche bancaire exécutée en arrière-plan après sa fermeture.

À l’ouverture de la PWA et lors de son retour au premier plan, MySold interroge
`/version.json` sans cache. Le numéro du build installé est comparé à celui
déployé sur le serveur. S’ils sont identiques, aucune fenêtre ne s’affiche.
S’ils diffèrent, une fenêtre affiche les deux versions et propose **Mettre à jour**
pour recharger l’application, ou **Plus tard** pour continuer. Un même build
refusé n’est pas proposé à nouveau pendant la session ouverte ; la recherche
manuelle reste accessible dans **Profil → Paramètres → Mettre à jour l’application**.
Enregistrer les modifications en cours avant de confirmer. La vérification
nécessite une connexion au serveur ; elle fonctionne en HTTPS ou sur localhost.
Le bouton installe la version déjà déployée par l’administrateur, sans mettre à
jour les conteneurs du serveur. Le contrôle est silencieux si le serveur est
injoignable ; le bouton des paramètres permet de réessayer.

Chaque compilation du frontend (GitHub Actions ou mode source) génère un numéro au format `AAAA.MM.JJ.HHMM`, par
exemple `2026.10.23.2145`, à partir de l’heure **Europe/Paris**, même si le serveur
utilise UTC. Ce numéro est intégré au client et publié dans `version.json`.
Un condensat du contenu versionne aussi le cache du service worker. Les scripts
de démarrage et le code Flutter portent ce numéro dans leur URL pour éviter
qu’une ancienne copie du navigateur soit réutilisée après installation. Le
client confirme le numéro et le condensat du worker actif avant de recharger ;
si l’installation échoue, il affiche une erreur au lieu de recharger en boucle.
L’activation retire les anciens caches de ressources MySold et Flutter, sans
effacer les préférences ou la session de l’utilisateur. Chaque
nouvelle version publiée doit avoir un numéro distinct ; éviter de publier deux
builds différents dans la même minute. Pour imposer un numéro en construction
manuelle ou en CI, après `flutter build web`, utiliser :

```sh
dart run tool/stamp_web_build.dart --build-version=2026.10.23.2145
```

Sans argument, le numéro est automatique. Relancer le script sur des fichiers
inchangés conserve leur numéro. Le numéro est visible dans **Paramètres → À propos**.
Après une première installation de cette fonctionnalité,
recharger une fois une ancienne PWA pour qu’elle dispose du contrôle automatique.

## Importer ses données Sold Up

1. Dans Sold Up, exporter **les données utilisateur au format CSV**, depuis
   Sécurité et confidentialité. Un rapport PDF ou CSV de transactions seul
   ne remplace pas cet export complet.
2. Créer un compte dans MySold et ouvrir Sécurité et confidentialité.
3. Importer le CSV et choisir le traitement des doublons.

Les chemins contenant l’ancien UID sont rattachés au compte actuellement connecté.
Les identifiants des comptes, catégories et investissements restent conservés
pour maintenir les liens entre documents. Le mot de passe et l’identité de
connexion ne sont jamais repris depuis le fichier. Les transactions restaurées
ne sont pas rejouées une seconde fois sur les soldes exportés. La valeur des
comptes auto-gérés est recalculée à partir des actifs importés.

Faire une sauvegarde avant un import : la restauration est progressive, elle ne
constitue pas une transaction unique sur l’ensemble du fichier. En cas d’arrêt,
les documents déjà enregistrés restent présents ; les options de doublons
permettent de reprendre l’import. Un export CSV n’est pas une sauvegarde des
identifiants de connexion, des sessions ou de la configuration du serveur.

## Comptes et sécurité

Les mots de passe utilisent scrypt. Les sessions utilisent un cookie HttpOnly,
SameSite Strict, expirent après sept jours et sont stockées hachées en base.
Les écritures exigent un en-tête applicatif et une origine présente dans
`APP_ORIGIN`. L’API
vérifie l’utilisateur propriétaire, les références, les montants et les lots
d’écritures atomiques. Les accès SQL utilisent des paramètres.

Le PIN conserve son rôle de verrouillage d’interface. Il ne chiffre pas la base
et ne remplace pas la connexion par mot de passe. La suppression du compte
requiert aussi une confirmation du mot de passe côté serveur ; les données
actives et les sessions sont supprimées dans la même transaction.

### Double authentification (MFA)

Dans **Profil → Paramètres → Sécurité et confidentialité → Double authentification**, saisir son mot de passe
actuel, puis scanner le QR code avec une application compatible TOTP, ou saisir
la clé manuellement. Confirmer un premier code à six chiffres pour activer la
protection. Le QR code est généré dans le navigateur, sans service externe.
La configuration en attente expire après dix minutes et ne bloque pas la
connexion tant qu’elle n’a pas été confirmée.

Enregistrer les dix codes de secours affichés à l’activation dans un endroit sûr,
distinct de l’appareil utilisé comme authentificateur. Ils ne sont affichés
qu’une fois et chacun ne peut servir qu’une fois. Ils permettent de se connecter
si l’authentificateur est perdu. Les paramètres permettent de les renouveler
(les anciens deviennent invalides), ou de désactiver le MFA, en confirmant le
mot de passe et un code TOTP ou de secours valide. Ces changements ferment les
autres sessions du compte.

À la connexion, le mot de passe est suivi du code d’authentificateur ou de
secours. Aucune session du compte n’est créée avant cette seconde vérification.
Cette étape expire après cinq minutes et les tentatives sont limitées côté
serveur. Les codes TOTP changent toutes les trente secondes ; un code déjà
accepté ne peut pas être réutilisé. Attendre le code suivant si nécessaire.
Activer la synchronisation automatique de l’heure sur le serveur et les appareils.
Le PIN reste un verrou d’interface séparé, présenté après la connexion.

Les secrets TOTP sont stockés dans des tables d’authentification distinctes des
documents utilisateur et ne figurent pas dans les exports CSV. Les codes de
secours sont conservés uniquement sous forme de condensats. Une sauvegarde
PostgreSQL contient les secrets TOTP : la protéger comme les autres données
sensibles de l’instance. Une réinitialisation de mot de passe ne retire pas le
MFA ; conserver les codes de secours avant de quitter l’écran d’activation.

Les tables MFA sont ajoutées automatiquement au démarrage de l’API après
`docker compose up -d --build`, y compris sur une instance existante.

Sans service d’e-mail externe, la récupération d’un compte se fait par
l’administrateur, sur la machine qui héberge MySold :

```sh
docker compose exec api python manage.py reset-password utilisateur@example.fr
```

Le nouveau mot de passe est demandé sans affichage et toutes les sessions du
compte sont révoquées. L’administrateur doit vérifier l’identité de la personne.

## Données persistantes et sauvegardes

Les nouvelles installations rangent leur base dans un dossier privé du projet :

```text
data/
  postgres/             base PostgreSQL complète
  backups/              exports .dump
  config/instance.env   copie privée de la configuration
```

`data/` et `.env` sont exclus de Git et conservés lors des reconstructions Docker.
La configuration active reste `.env` à la racine. Le script d’installation prépare
les dossiers ; PostgreSQL initialise sa base au premier démarrage.

**Ancienne instance :** sans `POSTGRES_STORAGE` dans son `.env`, l’ancien volume
Docker reste utilisé. Un `git pull` ne déplace aucune donnée. Pour passer une seule
fois à `data/postgres`, lancer explicitement la migration, puis redémarrer :

```sh
sudo sh scripts/data.sh migrate
sudo docker compose --env-file .env up -d --build
```

L’outil arrête proprement les services, copie et vérifie la base, puis met à jour
uniquement le choix du stockage. L’ancien volume et le secret sont conservés.
Il refuse d’écraser une destination déjà remplie. Ne pas supprimer les volumes
pour effectuer cette opération.

Pour sauvegarder la base sans arrêter le site :

```sh
sudo sh scripts/data.sh backup
```

L’export terminé apparaît dans `data/backups/` et la copie de `.env` est actualisée.
Le [guide des données](docs/DONNEES.md) détaille la copie du dossier complet après
arrêt de PostgreSQL, le transfert vers un autre serveur et la restauration d’un
export sur une nouvelle instance. Les sauvegardes contiennent notamment les
comptes et les secrets MFA : les conserver hors du serveur dans un emplacement
privé, et tester leur restauration.

## Vérifications

Les choix d’interface, les réglages du mode discret et les tests responsive sont
décrits dans [le guide de design](docs/DESIGN.md).

Le workflow vérifie aussi le téléchargement, l’intégrité et l’extraction des
releases, la correspondance avec les sources et la conservation de `.env` :

```sh
python3 -m unittest discover -s frontend/tool -p 'test_web_release.py' -v
python3 -m unittest discover -s scripts -p 'test_setup_shell.py' -v
python3 -m unittest discover -s scripts -p 'test_data_shell.py' -v
```

Les tests de stockage créent uniquement des conteneurs et volumes PostgreSQL
isolés, portant une étiquette propre à chaque exécution. Sur un hôte Linux avec
Docker, le parcours Compose complet est vérifié avec :

```sh
sudo env MYSOLD_STORAGE_INTEGRATION=1 python3 -m unittest discover -s scripts -p 'test_storage_integration.py' -v
```

Les tests d’intégration de l’API exigent une base séparée dont le nom se termine par
`_test`. Ils refusent la base d’application normale et réinitialisent uniquement
leur base de test.

```sh
docker compose exec db createdb -U mysold mysold_test
docker compose exec -e POSTGRES_DB=mysold_test api python -m unittest -v test_api test_mfa test_totp test_origin_policy
```

Si la base de test existe déjà, ne répéter que la seconde commande. Les tests
couvrent l’isolation, les écritures atomiques, les débits concurrents, les
investissements, les références, la suppression et les requêtes filtrées.

Pour travailler sur l’interface avec Flutter installé :

```sh
cd frontend
flutter pub get
dart run flutter_iconpicker:generate_packs --packs allMaterial
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build web --release --no-pub --no-tree-shake-icons --no-web-resources-cdn --no-wasm-dry-run
dart run tool/stamp_web_build.dart
```

Le catalogue d’icônes utilise des codes dynamiques : conserver
`--no-tree-shake-icons`. La configuration Nginx sert `/api/` et Flutter sur la
même origine. Un simple `flutter run` sans proxy vers l’API ne suffit pas.

## Polices et performances web

Les thèmes et l’authentification utilisent des polices embarquées. Noto Sans
fournit notamment l’espace fine insécable (`U+202F`) utilisé par le formatage
français des montants. Sa licence est conservée dans `frontend/assets/fonts/`.
Ne pas retirer cette police de la liste de repli : un caractère manquant peut
déclencher des téléchargements Google Fonts bloqués par la CSP et des tentatives
répétées de rendu. La CSP conserve `connect-src 'self'` et `font-src 'self' data:`.

Le bootstrap sélectionne la variante complète de CanvasKit, qui embarque sa
segmentation de texte et évite l’API dépréciée `Intl.v8BreakIterator` utilisée
par la variante Chromium. Le moteur est légèrement plus volumineux ; Nginx
compresse les scripts et fichiers WebAssembly avec gzip lorsque le navigateur
l’accepte. Après une modification, reconstruire et numéroter la PWA avec les
commandes ci-dessus (ou reconstruire l’image Docker), puis appliquer sa mise à jour.

## Licence

MySold est fourni sous une [licence personnelle d’auto-hébergement](LICENSE),
restrictive et non open source. L’installation personnelle et les modifications
privées sont permises. La redistribution, la revente et l’offre de service à des
tiers nécessitent une autorisation écrite. Les composants tiers conservent leurs
licences, disponibles dans les notices générées par Flutter et dans
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Les fonctionnalités d’affichage et de fork accordées par les
[conditions de GitHub](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service#5-license-grant-to-other-users)
restent distinctes de ces restrictions de redistribution et d’exploitation.

L’administrateur de chaque instance doit compléter ses coordonnées et sa politique
de conservation avant d’accueillir d’autres utilisateurs. La notice de
confidentialité de l’application a été adaptée à l’auto-hébergement.
