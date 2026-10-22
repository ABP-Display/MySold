# MySold

Votre budget et votre patrimoine, sur votre propre serveur.

MySold est l’édition web auto-hébergée de Sold Up. Elle reprend son interface
Flutter responsive : suivi mensuel, statistiques, vue globale, comptes,
catégories, investissements, thèmes, langues, mode discret et rapports PDF.
Elle utilise une API locale et PostgreSQL. Aucun projet Firebase, compte Google,
clé d’API bancaire ou service cloud applicatif n’est nécessaire.

## Démarrage

Prérequis : Docker avec Docker Compose v2. Node.js est uniquement nécessaire au
petit script de configuration ci-dessous ; Flutter et Python sont fournis dans
les images de construction. La première construction télécharge les images,
le SDK Flutter et les dépendances. Une fois construite, l’application ne dépend
pas d’un service tiers pour stocker les données ou authentifier les utilisateurs.

```sh
git clone https://github.com/ABP-Display/MySold.git
cd MySold
node scripts/setup.mjs
docker compose up -d --build
```

Ouvrir [MySold](http://localhost:8080), puis créer son compte. Aucun compte de
démonstration, mot de passe par défaut ni solde fictif n’est créé. Chaque compte
utilisateur possède son espace isolé.

Sans Node.js, créer `.env` à partir de `.env.example` et remplacer
`POSTGRES_PASSWORD` par un mot de passe aléatoire fort. Ne jamais publier `.env`.
Le script conserve toujours un `.env` déjà présent.

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
db : PostgreSQL + volume postgres_data
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
| `PUBLIC_ORIGIN` | Origine exacte du site, par exemple `https://finances.example.fr` |
| `WEB_PORT` | Port HTTP local, `8080` par défaut |
| `BIND_ADDRESS` | Interface d’écoute, `127.0.0.1` par défaut |
| `COOKIE_SECURE` | `true` lorsque l’accès au site utilise HTTPS |
| `ALLOW_REGISTRATION` | `false` pour fermer les nouvelles inscriptions |
| `FLUTTER_VERSION` | Version du SDK utilisée lors de la construction web |

Pour un serveur public, placer un reverse proxy HTTPS devant le port web,
configurer `PUBLIC_ORIGIN` avec le domaine réel et mettre `COOKIE_SECURE=true`.
Si le proxy tourne dans un autre conteneur, adapter son réseau ou l’interface
d’écoute. La base et l’API ne publient aucun port sur l’hôte. Ne pas exposer
PostgreSQL sur Internet. Changer le mot de passe dans `.env` après initialisation
ne change pas automatiquement le mot de passe du rôle PostgreSQL existant.

Après modification de la configuration :

```sh
docker compose up -d --build
docker compose ps
docker compose logs --tail=100 api web
```

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
Les écritures exigent un en-tête applicatif et une origine autorisée. L’API
vérifie l’utilisateur propriétaire, les références, les montants et les lots
d’écritures atomiques. Les accès SQL utilisent des paramètres.

Le PIN conserve son rôle de verrouillage d’interface. Il ne chiffre pas la base
et ne remplace pas la connexion par mot de passe. La suppression du compte
requiert aussi une confirmation du mot de passe côté serveur ; les données
actives et les sessions sont supprimées dans la même transaction.

Sans service d’e-mail externe, la récupération d’un compte se fait par
l’administrateur, sur la machine qui héberge MySold :

```sh
docker compose exec api python manage.py reset-password utilisateur@example.fr
```

Le nouveau mot de passe est demandé sans affichage et toutes les sessions du
compte sont révoquées. L’administrateur doit vérifier l’identité de la personne.

## Sauvegardes

Les données persistent dans le volume Docker `postgres_data`. `docker compose
down` conserve ce volume. **`docker compose down -v` le détruit.** Ne jamais
utiliser cette dernière commande sur une instance contenant des données à garder.

Sauvegarder la base, les secrets de l’instance et la configuration. Exemple de
dump binaire, en remplaçant les noms si vous les avez modifiés :

```sh
docker compose exec db pg_dump -U mysold -d mysold -Fc -f /tmp/mysold.dump
docker compose cp db:/tmp/mysold.dump ./mysold.dump
```

Stocker ce fichier chiffré hors du dépôt et tester une restauration sur une
instance séparée. La suppression d’un utilisateur de la base active ne retire
pas ses données des anciennes sauvegardes : définir une durée de rétention.

## Vérifications

Les tests d’intégration exigent une base séparée dont le nom se termine par
`_test`. Ils refusent la base d’application normale et réinitialisent uniquement
leur base de test.

```sh
docker compose exec db createdb -U mysold mysold_test
docker compose exec -e POSTGRES_DB=mysold_test api python -m unittest -v test_api
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
flutter build web --release --no-tree-shake-icons --no-web-resources-cdn
```

Le catalogue d’icônes utilise des codes dynamiques : conserver
`--no-tree-shake-icons`. La configuration Nginx sert `/api/` et Flutter sur la
même origine. Un simple `flutter run` sans proxy vers l’API ne suffit pas.

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
