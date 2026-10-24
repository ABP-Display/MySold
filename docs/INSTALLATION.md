# Installer et mettre à jour MySold

Ce guide concerne l’application complète avec Docker et PostgreSQL.
La [vitrine statique](README.md) sert uniquement à présenter l’interface.

## 1. Préparer le serveur

Disposer de Git, Docker et Docker Compose v2. Pour Ubuntu, suivre si nécessaire
la [documentation officielle Docker](https://docs.docker.com/engine/install/ubuntu/).
Les commandes ci-dessous utilisent `sudo` pour Docker et sont à exécuter
**ligne par ligne, sans ajouter de virgules**.

Node.js, Flutter et PostgreSQL ne sont pas à installer sur le serveur.
GitHub Actions compile le frontend ; Docker récupère automatiquement le build
correspondant aux sources. Aucun transfert manuel depuis un ordinateur n’est
nécessaire. Une connexion Internet est nécessaire pendant la construction.

## 2. Récupérer le projet

```sh
cd ~
git clone https://github.com/ABP-Display/MySold.git
cd MySold
```

Cloner sans `sudo` permet de modifier les fichiers avec son compte Ubuntu.
Si le projet a déjà été cloné avec `sudo`, consulter la section
[Dossier appartenant à root](#dossier-appartenant-à-root).

## 3. Créer le fichier privé `.env`

Pour une **nouvelle installation** :

```sh
sh scripts/setup.sh
nano .env
```

Le script crée `.env` à partir du modèle et génère automatiquement un secret
aléatoire de 64 caractères pour `POSTGRES_PASSWORD`. Il limite les permissions
du nouveau fichier à son propriétaire. Il ne remplace jamais un `.env` existant.

Dans Nano, enregistrer avec **Ctrl+O**, valider avec **Entrée**, puis quitter
avec **Ctrl+X**. Ne jamais publier `.env`, le committer, ni copier son contenu
dans des logs partagés.

### Les trois secrets à distinguer

| Secret | Utilisation | Où le choisir ? |
| --- | --- | --- |
| `POSTGRES_PASSWORD` | Connexion technique de l’API à PostgreSQL | Généré par `sh scripts/setup.sh` et conservé dans `.env` |
| Mot de passe du compte MySold | Connexion à l’application avec son adresse e-mail | Lors de la création du compte sur le site |
| PIN à six chiffres | Verrouillage de l’interface MySold | Dans le parcours de création du compte |

Le mot de passe PostgreSQL n’est pas un identifiant pour se connecter au site.
Il n’existe aucun compte administrateur ou utilisateur créé avec un mot de passe
par défaut. Le PIN ne remplace pas le mot de passe du compte.

### Si `.env` a été copié manuellement

Copier uniquement `.env.example` ne suffit pas. Si **aucune base n’a encore été
initialisée**, générer un secret puis éditer le fichier :

```sh
openssl rand -hex 32
nano .env
chmod 600 .env
```

Copier le secret affiché à droite de `POSTGRES_PASSWORD=`. Remplacer entièrement
`REPLACE_WITH_A_RANDOM_PASSWORD`, sans mettre d’espace autour du signe `=`.
Le script de configuration refusera de continuer si cette valeur d’exemple
est restée en place.

**Si l’application a déjà démarré avec une base**, ne pas remplacer simplement
le secret dans `.env` : suivre [Changer le mot de passe d’une base existante](#changer-le-mot-de-passe-dune-base-existante).

## 4. Configurer l’adresse du site

Modifier `APP_ORIGIN` et `COOKIE_SECURE` dans `.env` selon l’accès souhaité.
Remplacer le domaine ou l’adresse d’exemple par ceux de son propre serveur.

### Site public en HTTPS

Exemple de configuration à adapter :

```dotenv
WEB_PORT=28085
APP_ORIGIN=https://finances.votre-domaine.fr
COOKIE_SECURE=true
```

1. Configurer le DNS du domaine pour qu’il pointe vers le serveur.
2. Configurer le reverse proxy et son certificat HTTPS pour ce domaine.
3. Diriger le proxy vers `http://ADRESSE_DU_SERVEUR:28085`.
4. Ouvrir ensuite son domaine HTTPS dans le navigateur.

Un proxy installé directement sur le même serveur peut joindre
`http://127.0.0.1:28085`. Pour un proxy dans un conteneur, `127.0.0.1` désigne
ce conteneur : utiliser une adresse joignable du serveur ou un réseau Docker
partagé. Dans un réseau partagé avec le service `web`, le port interne est
`8080` et la destination est `http://web:8080`.

### Essai HTTP directement par adresse IP

Exemple, en remplaçant `192.0.2.10` par l’adresse réelle du serveur :

```dotenv
WEB_PORT=28085
APP_ORIGIN=http://192.0.2.10:28085
COOKIE_SECURE=false
```

Ouvrir alors `http://ADRESSE_DU_SERVEUR:28085`. Pour un essai uniquement sur
l’ordinateur qui héberge Docker, utiliser `APP_ORIGIN=http://localhost:28085`.
Depuis un autre appareil, `localhost` désigne cet autre appareil.
L’installation PWA et certaines permissions nécessitent HTTPS, sauf sur localhost.

### Règles pour `APP_ORIGIN`

- Renseigner exactement le protocole, le domaine ou l’IP, et le port non standard.
- Ne pas ajouter de chemin, de barre oblique finale ou de joker.
- Pour plusieurs accès, séparer les origines par des virgules.
- Remplacer les origines du modèle par celles de sa propre instance.

Exemple avec deux accès autorisés :

```dotenv
APP_ORIGIN=http://localhost:28085,https://finances.votre-domaine.fr
```

Une origine incorrecte peut permettre d’afficher le site mais bloquer la
connexion, l’inscription ou une écriture avec `403 Origine refusée`.
Le port `28085` est publié sur toutes les interfaces ; l’administrateur gère
son pare-feu et son reverse proxy. PostgreSQL et l’API ne publient pas de port
sur l’hôte. Changer `WEB_PORT` impose d’adapter le proxy et les origines HTTP.

## 5. Vérifier et démarrer

Depuis le dossier `MySold`, après avoir enregistré `.env` :

```sh
sh scripts/setup.sh
sudo docker compose --env-file .env config --quiet
sudo docker compose --env-file .env up -d --build
sudo docker compose --env-file .env ps
```

Le second appel au script vérifie le secret sans le modifier. La commande
`config --quiet` vérifie la configuration Compose et ne produit rien en cas
de succès ; elle ne teste pas le DNS ou le proxy.

Les services `db`, `api` et `web` doivent démarrer. Le service Web peut rester
quelques secondes en `health: starting` avant de devenir `healthy`.
Pour examiner un échec :

```sh
sudo docker compose --env-file .env logs --tail=100 db api web
```

Le workflow [Web release](https://github.com/ABP-Display/MySold/actions/workflows/web-release.yml)
doit avoir publié le build correspondant avant l’installation. Si le build
n’est pas encore disponible, attendre sa publication réussie puis relancer
la même commande `up -d --build`. La commande standard utilise uniquement
`compose.yaml` ; aucun `compose.prebuilt.yaml` n’est requis.

## 6. Créer son compte sur le site

Ouvrir l’adresse configurée, choisir **Créer un compte** et suivre le parcours :
adresse e-mail, mot de passe personnel respectant les critères affichés et PIN
à six chiffres. Utiliser ensuite l’e-mail et ce mot de passe pour se connecter.
L’authentificateur TOTP peut être ajouté dans **Profil → Paramètres → Sécurité
et confidentialité → Double authentification**.

Pour installer la PWA sur un téléphone, ouvrir le site HTTPS puis utiliser
« Installer l’application » ou « Ajouter à l’écran d’accueil » dans le navigateur.

## Mettre à jour une instance existante

Conserver le fichier `.env`, son secret PostgreSQL et le volume de données.
Ne pas refaire une copie du modèle par-dessus sa configuration et ne pas
supprimer le volume pour effectuer une mise à jour.

```sh
cd ~/MySold
git pull --ff-only
sudo docker compose --env-file .env up -d --build
sudo docker compose --env-file .env ps
```

Le site récupère le build publié correspondant au code. Si le frontend a changé,
attendre le succès du workflow Web release avant de lancer la mise à jour.
La PWA proposera ensuite sa propre mise à jour à l’utilisateur.

## Dossier appartenant à root

Pour un dépôt précédemment cloné avec `sudo`, garder les commandes Docker
ci-dessus mais utiliser aussi `sudo` pour les fichiers appartenant à root :

```sh
cd ~/MySold
sudo sh scripts/setup.sh
sudo nano .env
```

Lors d’une mise à jour, remplacer `git pull --ff-only` par :

```sh
sudo git pull --ff-only
```

Le script ne corrigera pas automatiquement un secret d’exemple dans un `.env`
existant. Si la base existe déjà, utiliser la procédure suivante.

## Changer le mot de passe d’une base existante

Cette procédure concerne une instance déjà démarrée, notamment si
`REPLACE_WITH_A_RANDOM_PASSWORD` a été utilisé lors de son premier démarrage.
Elle conserve les données. Prévoir une brève interruption de l’API pendant
la modification du secret et la recréation des conteneurs.

**Modifier seulement `.env` ne change pas le mot de passe d’une base déjà
initialisée.** Ce comportement est décrit dans la
[documentation de l’image PostgreSQL](https://hub.docker.com/_/postgres).

1. Générer un nouveau secret et le conserver pour les deux étapes suivantes :

   ```sh
   openssl rand -hex 32
   ```

2. Depuis le dossier MySold, ouvrir la console de la base en cours d’exécution :

   ```sh
   sudo docker compose --env-file .env exec db sh -c 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
   ```

   **Dans la console PostgreSQL**, saisir uniquement la commande suivante :

   ```text
   \password
   ```

   Entrer le nouveau secret deux fois lorsqu’il est demandé. Une fois la
   modification terminée et l’invite PostgreSQL réaffichée, quitter la console :

   ```text
   \q
   ```

   La commande [`\password`](https://www.postgresql.org/docs/17/app-psql.html)
   évite d’inscrire le secret en clair dans une commande SQL ou son historique.

3. De retour dans le terminal Ubuntu, mettre **exactement le même nouveau
   secret** dans `POSTGRES_PASSWORD`, sans changer le nom de base ou d’utilisateur :

   ```sh
   sudo nano .env
   sudo chmod 600 .env
   ```

4. Recréer les services avec cette configuration et vérifier leur état :

   ```sh
   sudo docker compose --env-file .env up -d --build
   sudo docker compose --env-file .env ps
   ```

Ne pas supprimer le volume PostgreSQL pour changer un mot de passe. En cas de
`password authentication failed`, vérifier la concordance entre le secret saisi
dans PostgreSQL et celui enregistré dans `.env`.

## Commandes courantes

Toutes ces commandes sont à exécuter depuis le dossier `MySold`.

| Action | Commande |
| --- | --- |
| Vérifier Compose sans afficher les secrets | `sudo docker compose --env-file .env config --quiet` |
| Installer, mettre à jour ou appliquer une modification de `.env` | `sudo docker compose --env-file .env up -d --build` |
| Voir l’état des services | `sudo docker compose --env-file .env ps` |
| Lire les derniers logs | `sudo docker compose --env-file .env logs --tail=100 db api web` |
| Arrêter les services en conservant les données | `sudo docker compose --env-file .env stop` |
| Redémarrer les conteneurs arrêtés sans changer leur configuration | `sudo docker compose --env-file .env start` |

Un changement de `.env` s’applique avec `up -d --build`, pas avec un simple
`start`. Les lignes `GET / ... 200 ... Wget` répétées toutes les 15 secondes
proviennent du contrôle de santé Web et sont normales.

Le [README principal](../README.md) détaille les sauvegardes, les comptes,
la sécurité, la compilation depuis les sources et les forks.
