# Protection des échanges et des données

## HTTPS/TLS

Déployer le site derrière un reverse proxy HTTPS avec un certificat valide,
TLS 1.2/1.3 et une redirection HTTP vers HTTPS. Définir le domaine personnel
dans `APP_ORIGIN`, `COOKIE_SECURE=true` et réserver le port interne HTTP au
proxy. Le proxy remplace `X-Forwarded-Proto` par `https` pour activer HSTS.
Compose ne délivre pas de certificat. HTTP reste possible uniquement sur la
boucle locale pour le développement ; le client et la politique d’origine
refusent les origines HTTP distantes.

TLS chiffre et authentifie le transport public. Le trafic HTTP dans le réseau
Docker reste interne : l’API et PostgreSQL n’ont aucun port publié. Un proxy
sur un autre serveur doit utiliser un réseau privé protégé ou un tunnel TLS
jusqu’à l’hôte MySold. HSTS ne remplace pas le certificat ni la configuration
du proxy. Les cookies de session sont HttpOnly, SameSite=Strict et Secure en HTTPS.

## AES-256-GCM au repos

Chaque utilisateur possède une clé aléatoire de 256 bits, créée avec son profil.
Elle est enveloppée en AES-256-GCM par la clé maître de l’instance. Cette clé
maître est créée automatiquement dans `data/keys/master.key`, permissions 0600
sur Linux, dossier 0700. Seul le service ponctuel d’initialisation peut écrire
dans ce dossier ; l’API le monte en lecture seule et fonctionne sans root.

Les documents complets (profils, comptes, catégories, investissements,
transactions et alertes) et les secrets TOTP actifs/en attente sont chiffrés
avec des nonces aléatoires de 96 bits renouvelés à chaque écriture. Les données
associées authentifiées lient chaque document à son utilisateur, son chemin et
ses métadonnées : déplacer un ciphertext ou altérer ces métadonnées fait échouer
sa lecture. Aucun mécanisme de repli en clair n’est utilisé en fonctionnement.
L’implémentation utilise la bibliothèque PyCA `cryptography`, pas un algorithme
maison. Les enveloppes portent une version pour une évolution ultérieure.

Les dates, types d’opération, identifiants de liaison et marqueurs de compte
support restent indexés en clair. Cela conserve les requêtes par période et
référence avec pagination SQL. Les montants, soldes, noms et libellés restent
chiffrés. Les requêtes explicites de tri/filtrage sur les champs privés sont
traitées après déchiffrement de la collection concernée ; les vues courantes
utilisent les dates indexées. Chaque requête ne déchiffre qu’une fois la clé
utilisateur, sans cache global durable de ces clés.

L’e-mail d’authentification reste lisible pour la connexion et l’administration.
Les mots de passe utilisent scrypt ; sessions, challenges et codes de secours
sont stockés sous forme de hachages. Aucun secret 2AF n’entre dans le CSV.

## Migration et sauvegardes

La conversion est automatique au démarrage, par lots de 200 lignes, avec reprise
après interruption et verrouillage des démarrages concurrents. Les anciens
documents et secrets TOTP sont préservés. Les tables annuelles retirées, si elles
existent encore, sont conservées mais leur JSON financier est également chiffré.
Aucun suivi annuel ni recalcul de référence n’est réactivé.

L’empreinte de la clé maître et l’authentification des clés utilisateur empêchent
un démarrage avec une autre clé. En cas d’erreur, restaurer la clé originale ;
ne pas en générer une nouvelle pour tenter de réparer. Le service `keys` ne
remplace jamais un fichier existant ou invalide.

Sauvegarder **la base ET `data/keys`** selon le [guide des données](DONNEES.md).
Changer un mot de passe ne change pas les clés. Aucune rotation automatique des
clés n’est implémentée ; remplacer `master.key` manuellement casse la lecture.
Les anciennes sauvegardes, WAL et exports lisibles nécessitent leur propre
protection : la migration ne les réécrit pas.

## Limites

Il s’agit d’un chiffrement au repos côté serveur, pas de chiffrement de bout en
bout. L’API déchiffre les données autorisées pour les afficher et les calculer.
Une fuite du dump seul ne révèle pas les champs chiffrés ; la possession de la
base **et** de la clé maître permet leur lecture. Une compromission complète du
serveur ou du navigateur connecté dépasse cette protection. Sauvegarder les
clés dans un emplacement privé, séparé des dumps lorsque c’est possible.

Références : [OWASP TLS](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html),
[OWASP stockage cryptographique](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html),
[PyCA AESGCM](https://cryptography.io/en/latest/hazmat/primitives/aead/#cryptography.hazmat.primitives.ciphers.aead.AESGCM).
