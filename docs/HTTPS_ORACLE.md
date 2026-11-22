# HTTPS direct entre les deux Nginx

Cette procédure conserve Nginx Proxy Manager (NPM) chez l’exploitant et active
HTTPS **dans le Nginx existant de MySold sur Oracle**. Aucun Caddy, nouveau domaine,
certificat auto-signé ou nouveau service cloud n’est nécessaire.

```text
Navigateur -- HTTPS --> NPM chez vous -- HTTPS vérifié --> Nginx MySold sur Oracle
                                                        --> API, réseau Docker privé
```

Le certificat existant de `mysold.ydoxide.fr` est réutilisé sur Oracle. Sa clé
privée est donc présente sur deux serveurs : les protéger tous les deux et
resynchroniser les fichiers après chaque renouvellement. Cette procédure de
transfert n’est pas un renouvellement automatique de la copie Oracle.

Le fichier `compose.yaml` suffit pour HTTP et HTTPS. HTTPS est activé avec
`TLS_ENABLED=true` et le port par défaut reste `28443`. Le port HTTP par défaut
est `28080`, lié à la boucle locale.
Ne pas remplacer `.env`, PostgreSQL, `data/keys` ou les données existantes.
Ne pas exécuter `docker compose down -v`. Les commandes ci-dessous concernent
Ubuntu/Linux, pas le terminal PowerShell de développement.

## Migrer une instance déjà en HTTPS

Après avoir récupéré la version qui contient le Compose unifié, supprimer
`COMPOSE_FILE=compose.yaml:compose.https.yaml` du `.env` (et de l’environnement
du terminal, si la variable y était exportée). Garder les réglages TLS existants
et ajouter `TLS_ENABLED=true`. Pour passer le diagnostic HTTP de `28085` à
`28080` avec NPM déjà en HTTPS sur `28443` :

```dotenv
WEB_PORT=28080
WEB_BIND_ADDRESS=127.0.0.1
TLS_ENABLED=true
```

Vérifier que le port `28080` est libre sur la VM. En cas de conflit, garder
`WEB_PORT=28085` ou choisir un autre port disponible. Ne pas déplacer les PEM
ni changer `TLS_CERT_GID` si le groupe existant est correct. Le domaine public,
le port HTTPS de NPM, PostgreSQL et les clés de chiffrement ne changent pas.
Passer ensuite à l’étape 5 pour valider et recréer les conteneurs.

## 1. Récupérer le certificat existant de NPM

Dans NPM : **SSL Certificates → certificat de mysold.ydoxide.fr → Download**.
L’archive contient la clé privée : ne pas la joindre à une conversation, un
ticket GitHub ou au dépôt. Pour un certificat Let’s Encrypt, les fichiers peuvent
porter un suffixe de génération (`fullchain3.pem`, `privkey3.pem`, etc.). Prendre
la paire correspondante et la nommer `fullchain.pem` et `privkey.pem`.
Ne pas utiliser uniquement `cert.pem` à la place de la chaîne complète.

Si l’export UI n’est pas disponible, sur la machine NPM, cette commande liste
les certificats et leurs chemins **sans afficher de clé** :

```bash
sudo docker exec nginx-proxy-manager certbot certificates
```

Adapter le nom du conteneur si nécessaire. Les chemins habituels sont
`/etc/letsencrypt/live/npm-N/fullchain.pem` et `privkey.pem` ; les liens Certbot
doivent être suivis lors du transfert, pas copiés comme des liens cassés.

## 2. Transférer uniquement ces deux fichiers par SSH

Sur Oracle :

```bash
umask 077
mkdir -p "$HOME/mysold-tls-incoming"
chmod 700 "$HOME/mysold-tls-incoming"
```

Depuis la machine qui possède les fichiers et un accès SSH vérifié à Oracle,
adapter les chemins locaux et vérifier l’IP actuelle de la VM :

```bash
scp /chemin/fullchain.pem /chemin/privkey.pem ubuntu@145.241.169.224:~/mysold-tls-incoming/
```

Utiliser les mêmes options `-i` et `-P` que pour votre connexion SSH habituelle,
si nécessaire. Ne pas désactiver la vérification de la clé du serveur SSH.
Ne pas placer les fichiers sous `frontend/`, `web/`, `docs/` ou tout répertoire public.

## 3. Vérifier et installer les fichiers sur Oracle

Vérifier le nom et la validité du certificat sans afficher la clé :

```bash
openssl x509 -in "$HOME/mysold-tls-incoming/fullchain.pem" -noout -subject -issuer -dates
openssl x509 -in "$HOME/mysold-tls-incoming/fullchain.pem" -noout -checkhost mysold.ydoxide.fr
openssl x509 -in "$HOME/mysold-tls-incoming/fullchain.pem" -noout -checkend 604800
```

La dernière commande vérifie qu’il reste plus de sept jours ; si elle échoue,
renouveler le certificat dans NPM avant de continuer. Vérifier aussi que les deux
empreintes de clé **publique** ci-dessous sont identiques (RSA et EC supportés) :

```bash
openssl x509 -in "$HOME/mysold-tls-incoming/fullchain.pem" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256
openssl pkey -in "$HOME/mysold-tls-incoming/privkey.pem" -pubout -outform DER | openssl dgst -sha256
```

Ne continuer que si les commandes réussissent et les empreintes concordent.
La clé doit être utilisable sans mot de passe interactif par Nginx.

Créer un groupe dédié, puis installer les fichiers avec des droits restreints :

```bash
cd /home/ubuntu/MySold
getent group mysold-tls || sudo groupadd --system mysold-tls
sudo install -d -o root -g mysold-tls -m 0750 "$PWD/data/tls"
sudo install -o root -g mysold-tls -m 0640 "$HOME/mysold-tls-incoming/fullchain.pem" "$PWD/data/tls/fullchain.pem"
sudo install -o root -g mysold-tls -m 0640 "$HOME/mysold-tls-incoming/privkey.pem" "$PWD/data/tls/privkey.pem"
getent group mysold-tls | cut -d: -f3
```

Le dernier nombre est le GID à utiliser ci-dessous. Ne pas utiliser le groupe
root ni mettre la clé en mode `0644` ou `0777`. Le service web reste non-root et
reçoit uniquement ce groupe supplémentaire. Le dossier est monté en lecture seule.

## 4. Configurer l’option HTTPS

Éditer le `.env` **existant**, sans modifier les identifiants PostgreSQL :

```bash
nano .env
```

Ajouter ou ajuster ces valeurs ; remplacer `GID_NUMERIQUE` par le nombre obtenu :

```dotenv
APP_ORIGIN=https://mysold.ydoxide.fr
COOKIE_SECURE=true
TLS_ENABLED=true
TLS_CERTS_DIR=./data/tls
TLS_CERT_GID=GID_NUMERIQUE
WEB_HTTPS_PORT=28443
WEB_HTTPS_BIND_ADDRESS=0.0.0.0
WEB_PORT=28080
WEB_BIND_ADDRESS=127.0.0.1
```

Si le proxy utilise encore HTTP, conserver son ancien port et l’adresse
d’écoute actuelle jusqu’à validation du trajet HTTPS. `TLS_CERTS_DIR` doit
contenir de vrais fichiers PEM et non des liens Certbot vers un dossier non
monté. Les certificats ne sont jamais construits dans l’image ni ajoutés au
paquet Web. Sans `TLS_ENABLED=true`, Nginx n’écoute pas sur le port TLS même
si Compose le réserve sur l’hôte.

Dans OCI, autoriser l’entrée **TCP 28443** depuis l’adresse publique de la maison
en `/32`, si elle est stable. Conserver l’accès HTTP utilisé et les règles SSH
pendant la transition. Il n’est pas nécessaire d’ouvrir 80 ou 443 sur Oracle :
NPM reste chargé de l’émission et du renouvellement du certificat chez vous.

## 5. Construire et valider avant la bascule

Lorsque les modifications ont été publiées et la release Web générée, mettre
le dépôt à jour. Ne pas exécuter le pull si des modifications locales empêchent
l’avance rapide : examiner d’abord les différences.

```bash
cd /home/ubuntu/MySold
git pull --ff-only
sudo docker compose config --quiet
sudo docker compose build web
sudo docker compose run --rm --no-deps web nginx -t
```

La validation ponctuelle ne publie aucun port et ne remplace pas le conteneur
actuel. Si le certificat est absent, illisible ou ne correspond pas à la clé,
Nginx refuse la configuration : corriger avant de lancer la commande suivante.

Après validation :

```bash
sudo docker compose up -d --build
sudo docker compose ps
curl --fail --head http://127.0.0.1:28080/
curl --fail --head --resolve mysold.ydoxide.fr:28443:127.0.0.1 https://mysold.ydoxide.fr:28443/
```

Les deux accès doivent réussir. Ne pas ajouter `-k`. Le `--resolve` vérifie
bien le certificat de `mysold.ydoxide.fr` tout en joignant directement Oracle,
sans changer le DNS public qui pointe toujours vers NPM.

Depuis la machine NPM, tester aussi le trajet réel vers l’IP Oracle :

```bash
curl --fail --head --resolve mysold.ydoxide.fr:28443:145.241.169.224 https://mysold.ydoxide.fr:28443/
```

Ce port n’est pas une nouvelle adresse de connexion pour les utilisateurs.
Ne pas ajouter cette URL avec port à `APP_ORIGIN` pour contourner une erreur :
l’adresse de l’application reste `https://mysold.ydoxide.fr`.

## 6. Passer le Proxy Host NPM en HTTPS

Dans le Proxy Host existant :

| Champ | Valeur |
| --- | --- |
| Domain Names | `mysold.ydoxide.fr`, inchangé |
| Scheme | `https` |
| Forward Hostname / IP | IP actuelle d’Oracle, `145.241.169.224` dans la capture |
| Forward Port | `28443` |

L’onglet SSL conserve son certificat public et la redirection HTTP vers HTTPS.
Avant d’activer la vérification du certificat amont, sur le serveur NPM :

```bash
sudo docker exec nginx-proxy-manager sh -c 'test -r /etc/ssl/certs/ca-certificates.crt && echo "Magasin CA disponible"'
```

Adapter le nom du conteneur. Si le magasin n’existe pas, examiner l’image NPM
avant de changer sa configuration. Dans **Advanced**, conserver les autres
réglages utiles et ajouter sans dupliquer une directive SSL existante :

```nginx
proxy_ssl_server_name on;
proxy_ssl_name mysold.ydoxide.fr;
proxy_ssl_verify on;
proxy_ssl_verify_depth 4;
proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
```

`proxy_ssl_name` permet de vérifier le nom du certificat même si la destination
réseau est une IP. Ne pas utiliser `proxy_ssl_verify off` pour masquer une erreur.
Tester ensuite la connexion, le PIN et les vues habituelles dans le navigateur.

## 7. Fermer le HTTP public après validation

Une fois NPM en HTTPS fonctionnel, confirmer `WEB_BIND_ADDRESS=127.0.0.1`
et `TLS_ENABLED=true` dans `.env`. Si le port ou l’adresse d’écoute a changé,
recréer le web :

```bash
sudo docker compose up -d web
```

Retirer également les autorisations OCI pour les ports HTTP actuel et ancien
(`28080` et `28085` si utilisés) et contrôler les
autres Security Lists/NSG pouvant encore l’autoriser. Garder SSH et l’accès
28443 nécessaire à NPM. Ne pas se fier uniquement à `ufw deny` pour un port Docker.

Depuis une machine extérieure, le premier accès doit échouer et le second réussir :

```bash
curl --head --connect-timeout 5 http://145.241.169.224:28080/
curl --fail --head https://mysold.ydoxide.fr/
```

Le HTTP local `http://127.0.0.1:28080/` reste disponible pour les diagnostics et
le contrôle de santé ; il ne traverse plus Internet.

## 8. Renouvellement et mises à jour

### Remplacer un certificat renouvelé

**NPM renouvelle sa copie, pas automatiquement celle d’Oracle.** Après chaque
renouvellement, répéter le transfert SSH et l’installation des **deux fichiers
correspondants**, comme aux étapes 2 et 3 :

- `/home/ubuntu/MySold/data/tls/fullchain.pem` : certificat et chaîne complète.
- `/home/ubuntu/MySold/data/tls/privkey.pem` : clé privée correspondant au certificat.

Adapter ce chemin si le dépôt est installé ailleurs. Utiliser le chemin absolu
évite que `~/MySold` désigne `/root/MySold` dans un terminal root. Ne jamais
transmettre la clé privée dans une conversation ou un ticket.

Une fois les deux fichiers remplacés, réappliquer leurs permissions et
valider/recharger sans arrêter le service :

```bash
cd /home/ubuntu/MySold
sudo chown root:mysold-tls data/tls/fullchain.pem data/tls/privkey.pem
sudo chmod 640 data/tls/fullchain.pem data/tls/privkey.pem

sudo docker compose exec -T web nginx -t &&
sudo docker compose exec -T web nginx -s reload
```

Le `&&` empêche le rechargement si la validation échoue. **Aucun rebuild ni
redémarrage du conteneur n’est nécessaire pour ce seul remplacement** : le
répertoire des certificats est monté en lecture seule dans le conteneur et
Nginx relit les fichiers au rechargement. Les connexions en cours peuvent finir
sur les anciens processus.

Vérifier ensuite le certificat réellement présenté par Oracle :

```bash
curl --fail --head --resolve mysold.ydoxide.fr:28443:127.0.0.1 https://mysold.ydoxide.fr:28443/
```

Ce test doit renvoyer `HTTP/1.1 200 OK`, sans option `-k`. Pour lire la nouvelle
date d’expiration du fichier sans afficher la clé :

```bash
sudo openssl x509 -in data/tls/fullchain.pem -noout -dates
```

Si la validation échoue, le processus actuel conserve le certificat précédemment
chargé ; corriger la paire de fichiers ou ses permissions avant le prochain
redémarrage. Le renouvellement a été testé avec une paire temporaire
dans des conteneurs isolés, pas avec le certificat de production.

Avant une utilisation durable, prévoir une synchronisation SSH automatisée
depuis NPM avec une identité dédiée, des permissions limitées et un contrôle
d’expiration. Aucun job de synchronisation distant n’est configuré par ce dépôt.
Ne pas supprimer les copies temporaires avant validation ; ensuite, les retirer
des dossiers de transfert/téléchargement et sauvegarder les clés uniquement dans
un emplacement privé protégé.

### Mettre à jour l’application

Pour les futures mises à jour, conserver le `.env`, les clés et les certificats :

```bash
git pull --ff-only
sudo docker compose up -d --build
```

Conserver `TLS_ENABLED=true` dans `.env`. Aucun fichier Compose additionnel
n’est requis. Ne jamais versionner une configuration privée contenant des secrets.

## Références

- [Nginx : configuration HTTPS](https://nginx.org/en/docs/http/configuring_https_servers.html).
- [Nginx : rechargement de la configuration](https://nginx.org/en/docs/control.html).
- [Nginx : validation du certificat amont](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_ssl_verify).
- [Docker : interaction avec UFW](https://docs.docker.com/engine/network/packet-filtering-firewalls/#docker-and-ufw).
