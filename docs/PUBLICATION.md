# Publication et référencement

L’application se trouve à `/app/` (navigation Flutter `/app/#/...`). Elle porte une directive
`noindex` : ni les comptes ni les routes privées ne doivent devenir des résultats
de recherche. Les API restent soumises à leur authentification et à leur contrôle
d’accès. `robots.txt` n’est pas une protection des données.

La page d’accueil publique **`/`** présente MySold en HTML rendu côté serveur, sans
charger Flutter, JavaScript ou données utilisateur pour un visiteur anonyme. C’est cette adresse
qui est destinée aux recherches et au partage. Elle contient titre, description,
URL canonique, aperçu Open Graph/Twitter, favicon, image descriptive et liens vers
les notices publiques. Le bouton « Accéder à l’application » ouvre `/app/` :
connexion pour les visiteurs. Quand le navigateur envoie un cookie de session
valide sur l’accueil, le serveur redirige directement vers `/app/`, où l’écran
PIN prend le relais. Le cookie de session conserve `SameSite=Strict` ; il peut
ne pas accompagner une première visite provenant d’un autre site.
La présentation reste accessible à `/?presentation=1`, même avec une session.
L’ancienne URL `/decouvrir/` redirige vers l’accueil.
Les captures WebP montrent l’application locale avec un compte et des données
fictives : dépenses et revenus du mois, statistiques mensuelles et annuelles.
Chaque vue utilise une capture adaptée aux petits écrans ; l’aperçu social JPEG
est au format 1 200 × 630 px. Les notices s’adaptent au thème du navigateur.

## Configurer cette instance

Conserver le `.env` et les données existants. Ajouter ou adapter uniquement les
valeurs de publication, jamais le mot de passe PostgreSQL ou la clé de chiffrement.

Pour l’instance officielle :

```dotenv
APP_ORIGIN=https://mysold.ydoxide.fr
COOKIE_SECURE=true
PUBLIC_SITE_URL=https://mysold.ydoxide.fr
PUBLIC_INDEXING=true
PUBLIC_OPERATOR_NAME=ydoxide
PUBLIC_CONTACT_URL=https://github.com/ABP-Display/MySold
```

`PUBLIC_SITE_URL` doit être une origine exacte déjà autorisée dans `APP_ORIGIN`,
sans chemin ni paramètres. Si elle est vide, une origine HTTPS valide de
`APP_ORIGIN` est utilisée avant une éventuelle origine locale. Une URL explicite
invalide désactive l’indexation plutôt que de faire confiance au header `Host`.
Une instance HTTP locale n’est jamais annoncée aux moteurs. Pour une instance
privée ou un environnement de préproduction, mettre `PUBLIC_INDEXING=false`.

Les champs suivants sont publics. Renseigner des informations **réelles**, selon
le statut de l’exploitant et le contrat d’hébergement :

- `PUBLIC_OPERATOR_ADDRESS` : identification et adresse requises pour l’exploitant.
- `PUBLIC_CONTACT_EMAIL` : canal confidentiel recommandé pour les demandes de données.
- `PUBLIC_HOSTING_NAME`, `PUBLIC_HOSTING_ADDRESS`, `PUBLIC_HOSTING_CONTACT` : hébergeur.
- `PUBLIC_HOSTING_REGION` : localisation effective et éventuels transferts de données.
- `PUBLIC_LOG_RETENTION` : durée et procédure réellement appliquées aux journaux.
- `PUBLIC_BACKUP_RETENTION` : durée, purge et traitement des données supprimées en restauration.

Les valeurs manquantes sont signalées dans les notices ; aucune adresse, durée
ou purge n’est inventée. Le nom `ydoxide` n’est utilisé automatiquement que pour
l’origine officielle `https://mysold.ydoxide.fr`. Les autres instances doivent
renseigner leur propre exploitant.

Le dépôt GitHub est un contact **public**, pas une boîte de réception privée.
Ne pas demander aux utilisateurs d’y publier un CSV, une adresse e-mail ou des
informations financières. Prévoir un canal confidentiel pour les demandes de
droits et signalements sensibles avant une ouverture à des utilisateurs tiers.
Faire valider les informations juridiques selon le statut réel de l’exploitant.

## Pages et indexation

| Adresse | Usage |
| --- | --- |
| `/` | Présentation publique indexable |
| `/decouvrir/` | Redirection permanente vers l’accueil |
| `/confidentialite/` | Politique de confidentialité de l’instance |
| `/conditions/` | Conditions générales d’utilisation |
| `/mentions-legales/` | Exploitant, contact et hébergement |
| `/cookies/` | Cookie technique, préférences et cache PWA |
| `/sitemap.xml` | Liste des cinq pages publiques, en URLs absolues |
| `/robots.txt` | Consignes de parcours et lien vers le sitemap |
| `/app/` et `/index.html` | Application privée, `noindex, follow` |

Une page inconnue renvoie réellement **404**, avec une page de retour adaptée,
et non un statut 200 accompagné de l’application. Les erreurs API restent en JSON.
Les liens sans slash final des pages publiques fonctionnent aussi derrière un
reverse proxy HTTPS, sans redirection vers une adresse HTTP interne.

La [vitrine GitHub Pages](README.md) utilise le même modèle HTML que l’accueil
officiel, sans démo interactive. Elle reste marquée `noindex` et son canonique
renvoie vers la présentation officielle pour éviter deux pages concurrentes. Le cache
PWA ne remplace pas les pages publiques ou leurs 404 par l’écran de connexion.

Après déploiement, créer une propriété du domaine dans Google Search Console,
la vérifier par DNS, puis soumettre
`https://mysold.ydoxide.fr/sitemap.xml`. Inspecter `/` et demander son
indexation. La vérification DNS et cette demande nécessitent l’accès du
propriétaire ; le code ne les effectue pas. Aucun positionnement ni délai
d’indexation n’est garanti. Les aperçus de partage peuvent être mis en cache
par les réseaux sociaux et nécessiter une nouvelle inspection de l’URL publique.

### Vérifier le déploiement

Mettre à jour les images `web` **et** `api` : Nginx route les pages publiques
vers Flask. Avec l’option HTTPS Oracle, conserver les deux fichiers Compose ou
la variable `COMPOSE_FILE` documentée dans le [guide HTTPS](HTTPS_ORACLE.md).

```bash
curl --fail --head https://mysold.ydoxide.fr/
curl --fail --head https://mysold.ydoxide.fr/app/
curl --fail --head https://mysold.ydoxide.fr/conditions/
curl --fail --head https://mysold.ydoxide.fr/confidentialite/
```

Les quatre adresses doivent répondre en HTML avec un statut 200. Une réponse
JSON `http-error` sur une notice indique que la requête n’est pas servie par la
route publique attendue. Vérifier que l’API a bien été recréée et que Nginx Proxy
Manager transmet le chemin complet à Nginx MySold, sans le préfixer par `/api`.

## Cookies et audience

MySold n’intègre aucun outil de mesure d’audience ni publicité. Les pages
publiques n’utilisent aucun stockage navigateur. L’application utilise son cookie
de session, ses préférences et le cache technique de la PWA. Il n’y a donc pas de
faux bandeau d’acceptation de traceurs publicitaires. Le lien « Cookies » décrit
les fonctions existantes. Si un exploitant ajoute des traceurs non nécessaires,
il doit les bloquer avant consentement et permettre de refuser et de retirer
l’accord aussi simplement. Une extension ajoutée au reverse proxy doit également
être prise en compte.

## Contrôles avant ouverture

Si le reverse proxy est sur une autre machine, le [guide HTTPS Oracle](HTTPS_ORACLE.md)
décrit l’option TLS du Nginx MySold existant. Le certificat et sa clé restent hors
du dépôt ; le renouvellement doit être resynchronisé depuis le proxy.

- HTTPS valide et redirection HTTP vers HTTPS ; proxy et pare-feu sans accès HTTP direct distant.
- `.env`, clés, sauvegardes et base non publiés ; seuls les ports web/proxy sont exposés.
- Vérification manuelle des notices après renseignement de l’exploitant, de l’hébergeur et des durées.
- Liens, images, boutons légaux de connexion/inscription et page 404.
- Inscription autorisée ou fermée selon le public visé avec `ALLOW_REGISTRATION`.
- Aucun ajout de suivi d’audience implicite au proxy, au CDN ou à la page.
- Sauvegarde PostgreSQL **et** `data/keys`, avec procédure de restauration testée.

Ne jamais exécuter les suites `backend/test_api.py` et assimilées sur une base
réelle : elles exigent et réinitialisent une base distincte dont le nom finit
par `_test`.

## Suivi de la checklist officielle

État au 21 novembre 2026 pour `mysold.ydoxide.fr`. Les fonctions présentes dans
le dépôt ne prouvent pas que les réglages correspondants sont actifs sur la VM.
Le test communiqué par l’exploitant confirme un HTTP 200 en HTTPS sur le port
TLS local d’Oracle, avec vérification du certificat. Il ne confirme pas à lui
seul la configuration du proxy à domicile ou les règles réseau OCI.

| Point | État et action restante |
| --- | --- |
| Politique de confidentialité et CGU | Pages implémentées. Compléter les informations d’exploitant, l’hébergeur contractuel, les durées réelles et un canal confidentiel ; relire les pages déployées. |
| Localisation de l’hébergement | Oracle, région Europe Paris, déclarée par l’exploitant. Renseigner `PUBLIC_HOSTING_REGION` et les coordonnées exactes de l’hébergeur selon le contrat. |
| Secrets côté serveur | Configuration prévue hors du dépôt et des fichiers publics. Vérifier les droits et les sauvegardes de `.env`, `data/keys` et `data/tls` sur la VM. |
| HTTPS sur les deux trajets | TLS Oracle testé localement. Confirmer le proxy NPM en HTTPS avec validation du certificat amont, fermer le HTTP public et limiter le port TLS aux sources nécessaires. |
| Renouvellement TLS | [Procédure de remplacement et rechargement](HTTPS_ORACLE.md#8-renouvellement-et-mises-à-jour) documentée. La synchronisation NPM vers Oracle et la surveillance d’expiration restent à automatiser. |
| Cookies | Notice implémentée ; aucun outil publicitaire ou d’audience intégré. Vérifier qu’aucun traceur non nécessaire n’a été ajouté au proxy ou ailleurs avant de décider d’un bandeau de consentement. |
| Métadonnées, aperçu et favicon | Implémentés sur les pages publiques. Contrôler le rendu de l’accueil et les aperçus de partage après déploiement. |
| Sitemap et robots | Générés par le serveur. Vérifier `PUBLIC_SITE_URL`, `PUBLIC_INDEXING` et les réponses publiques ; vérifier le domaine dans Search Console et soumettre le sitemap. |
| Images et textes alternatifs | Aperçu compressé et descriptions intégrés. Maintenir ces contrôles pour les futures images. |
| Mobile, contraste et chargement | Contrôles locaux réalisés sur les pages publiques. Mesurer encore sur le domaine réel, Android/PWA et réseau mobile ; la VM et le proxy peuvent modifier le résultat. |
| Page 404 et liens | Implémentés et contrôlés localement. Vérifier aussi les réponses sur le domaine final derrière NPM. |
| Validation et protection contre les abus | Validation serveur et limites de tentatives présentes. Confirmer les adresses IP transmises par la chaîne de proxies et surveiller les abus ; aucun CAPTCHA n’est revendiqué. |
| Sauvegardes et récupération | Procédure documentée. Automatiser les copies privées hors VM de PostgreSQL et des clés, appliquer une rétention et tester une restauration isolée. |
| Mesure d’audience | Facultative et non intégrée. Ne rien ajouter par défaut. |

Ordre conseillé : terminer les contrôles réseau/TLS, compléter les notices et
les sauvegardes, effectuer les vérifications sur le domaine final, puis soumettre
le sitemap. La mise en ligne des notices ne constitue pas, seule, une validation
de conformité juridique ni un audit de sécurité exhaustif.

## Références

- [Flutter : séparer le contenu HTML public de l’application](https://docs.flutter.dev/platform-integration/web/faq#search-engine-optimization-seo).
- [Google : contrôler l’indexation](https://developers.google.com/search/docs/crawling-indexing/control-what-you-share).
- [CNIL : cookies et traceurs](https://www.cnil.fr/fr/cookies-et-autres-traceurs/que-dit-la-loi).
- [CNIL : information des personnes](https://www.cnil.fr/fr/conformite-rgpd-information-des-personnes-et-transparence).
