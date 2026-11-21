# Publication et référencement

L’application reste à `/` (navigation Flutter `/#/...`). Elle porte une directive
`noindex` : ni les comptes ni les routes privées ne doivent devenir des résultats
de recherche. Les API restent soumises à leur authentification et à leur contrôle
d’accès. `robots.txt` n’est pas une protection des données.

La page publique **`/decouvrir/`** présente MySold en HTML rendu côté serveur, sans
charger Flutter, JavaScript, session ou données utilisateur. C’est cette adresse
qui est destinée aux recherches et au partage. Elle contient titre, description,
URL canonique, aperçu Open Graph/Twitter, favicon, image descriptive et liens vers
les notices publiques. L’image WebP de 1 200 × 630 px provient exclusivement de la
démo fictive et pèse environ 21 Ko. Les pages s’adaptent au thème du navigateur.

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
| `/decouvrir/` | Présentation publique indexable |
| `/confidentialite/` | Politique de confidentialité de l’instance |
| `/conditions/` | Conditions générales d’utilisation |
| `/mentions-legales/` | Exploitant, contact et hébergement |
| `/cookies/` | Cookie technique, préférences et cache PWA |
| `/sitemap.xml` | Liste des cinq pages publiques, en URLs absolues |
| `/robots.txt` | Consignes de parcours et lien vers le sitemap |
| `/` et `/index.html` | Application privée, `noindex, follow` |

Une page inconnue renvoie réellement **404**, avec une page de retour adaptée,
et non un statut 200 accompagné de l’application. Les erreurs API restent en JSON.
Les liens sans slash final des pages publiques fonctionnent aussi derrière un
reverse proxy HTTPS, sans redirection vers une adresse HTTP interne.

La démo GitHub Pages reste séparée et marquée `noindex` ; son canonique renvoie
vers la présentation officielle pour éviter deux pages concurrentes. Le cache
PWA ne remplace pas les pages publiques ou leurs 404 par l’écran de connexion.

Après déploiement, créer une propriété du domaine dans Google Search Console,
la vérifier par DNS, puis soumettre
`https://mysold.ydoxide.fr/sitemap.xml`. Inspecter `/decouvrir/` et demander son
indexation. La vérification DNS et cette demande nécessitent l’accès du
propriétaire ; le code ne les effectue pas. Aucun positionnement ni délai
d’indexation n’est garanti. Les aperçus de partage peuvent être mis en cache
par les réseaux sociaux et nécessiter une nouvelle inspection de l’URL publique.

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

## Références

- [Flutter : séparer le contenu HTML public de l’application](https://docs.flutter.dev/platform-integration/web/faq#search-engine-optimization-seo).
- [Google : contrôler l’indexation](https://developers.google.com/search/docs/crawling-indexing/control-what-you-share).
- [CNIL : cookies et traceurs](https://www.cnil.fr/fr/cookies-et-autres-traceurs/que-dit-la-loi).
- [CNIL : information des personnes](https://www.cnil.fr/fr/conformite-rgpd-information-des-personnes-et-transparence).
