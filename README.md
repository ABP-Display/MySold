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

Prérequis : Git, Docker et Docker Compose v2. Aucun script d’installation,
Node.js, Python ou Flutter n’est nécessaire sur la machine hôte.

```sh
git clone https://github.com/ABP-Display/MySold.git
cd MySold
cp .env.example .env
# Modifier .env : choisir le mot de passe, les noms et l’adresse du site.
docker compose up -d --build
```

Ouvrir **http://localhost:28085**, puis choisir **Créer un compte**. Le mot de
passe du compte et le PIN sont choisis sur le site ; aucun compte par défaut
n’est créé. Si Docker exige les droits administrateur, préfixer les commandes
Docker par `sudo`.

Le modèle `.env.example` contient des valeurs génériques et des commentaires.
Après la copie, renseigner **`POSTGRES_PASSWORD`** dans `.env` avant le lancement ;
le nom de base (`POSTGRES_DB`), l’utilisateur (`POSTGRES_USER`) et l’adresse du
site sont personnalisables. Une valeur de mot de passe vide bloque le lancement.
Compose crée directement `data/postgres` et `data/backups`. Aucun mot de passe
n’est généré ni aucun fichier de configuration modifié automatiquement.

### Domaine personnel ou accès distant

Dans le `.env` copié depuis le modèle, choisir ses valeurs avant le premier
démarrage. Exemple générique à remplacer par ses propres informations :

```dotenv
POSTGRES_DB=mon_budget
POSTGRES_USER=mon_utilisateur
POSTGRES_PASSWORD='REMPLACER_PAR_UN_MOT_DE_PASSE_LONG_ET_UNIQUE'
APP_ORIGIN=https://finances.votre-domaine.fr
COOKIE_SECURE=true
```

Le DNS et le reverse proxy HTTPS doivent pointer vers le serveur, sur le port
`28085`. Remplacer les domaines du modèle par celui de sa propre instance.
Pour un accès HTTP par IP, renseigner plutôt
`APP_ORIGIN=http://ADRESSE_DU_SERVEUR:28085` et `COOKIE_SECURE=false`.
`localhost` désigne l’ordinateur sur lequel le navigateur est ouvert.

Conserver `.env` privé et utiliser un mot de passe long et unique. Les mots de
passe des comptes MySold sont choisis séparément sur le site.
Le port `28085` est publié sur toutes les interfaces ; l’administrateur gère
le pare-feu, le DNS et le proxy. Après une modification de `.env`, relancer :

```sh
docker compose up -d --build
```

Le [guide d’installation](docs/INSTALLATION.md) détaille la configuration et le
[guide des données](docs/DONNEES.md) décrit les sauvegardes et les transferts.

### Mises à jour

```sh
git pull --ff-only
docker compose up -d --build
```

Conserver `data/` et `.env`. Les reconstructions des images ne
suppriment ni la base ni le secret. La mise à jour de la PWA est ensuite proposée
aux utilisateurs quand une nouvelle version du frontend est disponible.

### Construction automatique, développement et forks

GitHub Actions compile les sources Flutter modifiées et publie leur release Web
avec un numéro de build daté. Le Dockerfile par défaut télécharge la release
correspondant exactement aux sources et vérifie son intégrité. Une petite machine
peut ainsi installer MySold sans compiler Flutter localement. Internet est
nécessaire pendant la construction ; les données restent sur l’instance.

Si la release n’est pas encore publiée, attendre la réussite du workflow
**Web release**, puis relancer la commande Docker. Aucune compilation Flutter
de secours n’est lancée automatiquement sur le serveur.

La compilation complète depuis les sources reste disponible pour le développement :

```sh
docker compose -f compose.yaml -f compose.source.yaml up -d --build
```

Ce mode exige davantage de mémoire et utilise `FLUTTER_VERSION` (3.44.0 par
défaut). `compose.source.yaml` est conservé pour ce besoin précis.

Pour un fork public, activer GitHub Actions et définir
`MYSOLD_REPOSITORY=PROPRIETAIRE/DEPOT` dans `.env`. Les sources modifiées
nécessitent leur propre release. Un fork privé peut utiliser la compilation
locale depuis les sources.

### Vérifier le démarrage

```sh
docker compose ps
docker compose logs --tail=100 db api web
```

Les trois services `db`, `api` et `web` doivent être sains. Le premier démarrage
peut demander quelques minutes, le temps de télécharger et construire les images.

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
db : PostgreSQL + dossier data/postgres
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
| `POSTGRES_PASSWORD` | Obligatoire : mot de passe technique choisi dans `.env` pour PostgreSQL et l’API |
| `POSTGRES_DB`, `POSTGRES_USER` | Nom de base et utilisateur PostgreSQL |
| `WEB_PORT` | Port HTTP local, `28085` par défaut |
| `APP_ORIGIN` | Origines autorisées pour les écritures, séparées par des virgules ; modèle local : `http://localhost:28085` |
| `COOKIE_SECURE` | `true` lorsque l’accès au site utilise HTTPS |
| `ALLOW_REGISTRATION` | `false` pour fermer les nouvelles inscriptions |
| `MYSOLD_REPOSITORY` | Dépôt GitHub public publiant les releases Web ; défaut `ABP-Display/MySold` |
| `FLUTTER_VERSION` | SDK du mode `compose.source.yaml` uniquement ; défaut `3.44.0` |

MySold publie le port `28085` sur toutes les interfaces. Toute machine pouvant
joindre ce port peut charger le site ; les données restent protégées par la
connexion utilisateur. Les écritures exigent une origine autorisée.
L’administrateur gère son pare-feu, son DNS et son reverse proxy.

**Chaque administrateur doit remplacer `APP_ORIGIN` par le domaine personnel de
son instance.** Le modèle utilise `localhost` pour les essais locaux. Exemple pour votre propre site HTTPS :

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
Docker Compose lit automatiquement le fichier `.env` du projet. Après une
modification de `APP_ORIGIN`, recréer les conteneurs avec la commande ci-dessous.

Pour HTTPS, diriger le proxy vers `http://ADRESSE_DU_SERVEUR:28085` et définir
`COOKIE_SECURE=true` dans `.env`. Un proxy installé directement sur le même
serveur peut utiliser `http://127.0.0.1:28085`. Dans un conteneur proxy,
`127.0.0.1` désigne ce conteneur : utiliser une adresse joignable du serveur,
ou un réseau Docker partagé avec `web` et la destination `http://web:8080`.
Le port interne reste `8080`, même si `WEB_PORT` est modifié.

La base et l’API ne publient aucun port sur l’hôte. Ne pas exposer
PostgreSQL sur Internet. Conserver le mot de passe dans `.env`. Modifier
`POSTGRES_PASSWORD`, `POSTGRES_USER` ou `POSTGRES_DB` après initialisation ne
modifie pas les identifiants ni le nom d’une base déjà créée.

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

La création de compte propose une **quatrième étape facultative** : scanner le
QR code ou copier la clé dans son application d’authentification, puis confirmer
un code à six chiffres. La protection devient active uniquement après validation
par le serveur. Le bouton **Passer pour le moment** termine l’inscription sans
activer la 2FA. Après activation, sauvegarder les codes de secours affichés avant
d’accéder à son espace.

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

Les volumes sont déclarés directement dans `compose.yaml` :

```text
data/
  postgres/                  base PostgreSQL complète
  backups/                   emplacement des exports de la base
```

Docker crée ces dossiers au démarrage. `data/` et `.env` sont exclus de Git.
Conserver l’ensemble de `data/` et le fichier `.env` pour transférer une instance.
Copier les fichiers PostgreSQL uniquement après un arrêt propre des services,
en conservant les permissions.

Pour exporter la base sans arrêter le site :

```sh
docker compose exec db sh -ec 'umask 077; pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc -f "/backups/mysold-$(date -u +%Y%m%dT%H%M%SZ).dump"'
```

Le [guide des données](docs/DONNEES.md) décrit la restauration, la copie vers un
autre serveur et les permissions. Les exports contiennent les comptes et les
secrets MFA : conserver une copie privée hors du serveur.

## Vérifications

Les choix d’interface, les réglages du mode discret et les tests responsive sont
décrits dans [le guide de design](docs/DESIGN.md).

Le workflow vérifie les releases, le refus d’un mot de passe manquant et une
installation depuis le modèle `.env.example` personnalisé, avec création de
compte et conservation des données après reconstruction :

```sh
python3 -m unittest discover -s frontend/tool -p 'test_web_release.py' -v
sudo env MYSOLD_INSTALLATION_TEST=1 python3 -m unittest discover -s backend -p 'test_installation.py' -v
```

Le test d’installation utilise un projet Compose temporaire, un port aléatoire
sur localhost et son propre stockage. Sur Linux, les droits root permettent de
nettoyer les fichiers PostgreSQL appartenant au conteneur après le test.
Il ne démarre pas le projet de l’utilisateur.

Les tests d’intégration de l’API exigent une base séparée dont le nom se termine par
`_test`. Ils refusent la base d’application normale et réinitialisent uniquement
leur base de test.

```sh
docker compose exec db sh -ec 'createdb -U "$POSTGRES_USER" mysold_test'
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
