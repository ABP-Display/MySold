# Audit de publication MySold

Audit ciblé du code et vérifications locales du 21 novembre 2026. Il ne s’agit
ni d’un pentest exhaustif, ni d’une certification juridique ou d’accessibilité.
Aucune écriture de test ni tentative de connexion n’a été effectuée en production.

## Constats et corrections

| Avant | Après | Motif |
| --- | --- | --- |
| Application Flutter seule à la racine | Présentation HTML publique à `/decouvrir/`, sans changer l’entrée de l’application | Contenu lisible sans moteur Flutter et sans connexion |
| Notices disponibles principalement dans l’interface | Pages publiques de confidentialité, conditions, mentions légales et cookies | Information accessible avant toute saisie et depuis connexion/inscription |
| Absence de sitemap, robots et canonique publics | Sitemap des cinq documents publics et URLs construites depuis une configuration d’origine autorisée | Référencement sans publier les routes privées ni refléter un header Host arbitraire |
| Aperçu social absent | Métadonnées Open Graph/Twitter, JPEG 1 200 × 630 et aperçu WebP compact | Partage identifiable, issu uniquement de la démo fictive |
| URLs inexistantes renvoyant l’application avec un statut 200 | Réponse HTTP 404 avec navigation de retour ; erreurs API toujours JSON | Pas de faux résultats valides pour les moteurs ou clients |
| Repli hors ligne pour toute navigation | Repli réservé à `/` et `/index.html` | Ne pas remplacer les notices ou une 404 publique par l’application |
| CSS de la vitrine non adaptée aux nouveaux documents | Texte contrasté, images dimensionnées, navigation clavier et affichage mobile | Lisibilité, absence de décalage d’image et de débordement constaté |
| Cookie technique sans page dédiée | Notice détaillant la session, les préférences et le cache PWA | Pas d’ajout de suivi ou de faux consentement publicitaire |

## Sécurité vérifiée

- Les nouveaux documents publics ne consultent aucune session, aucun document
  financier et aucune base SQL ; les tests échouent si une connexion SQL y est tentée.
- Les textes d’environnement sont échappés par Jinja. Les URLs de contact et
  d’indexation sont contrôlées ; aucun secret d’environnement n’est injecté.
- La CSP publique interdit scripts, formulaires et contenus externes. Celle de
  l’application conserve les besoins de Flutter et limite les destinations des formulaires.
- Les chemins de fichiers cachés ne sont pas servis par Nginx. Les API ne sont
  pas interceptées par la règle de cache des images et restent authentifiées.
- Les suites API vérifient isolation entre utilisateurs, validation métier,
  refus des origines étrangères, injection SQL sur le tri, limites de tentatives,
  cookies HTTPS, déconnexion, TOTP et authentification du chiffrement au repos.
- `.env`, clés et données sont ignorés par Git ; les contextes Docker excluent
  les fichiers `.env*`. Le scan ciblé des fichiers versionnés n’a pas trouvé de
  motif de clé privée, de jeton GitHub, de clé AWS ou de clé Google correspondant
  aux signatures recherchées. Ce scan ne prouve pas l’absence de tout secret.
- Aucun CAPTCHA ou prestataire d’analyse tiers obligatoire n’a été ajouté.

## Vérifications réellement effectuées

- 495 tests Flutter non navigateur réussis ; contrôle du catalogue des nouveaux textes.
- 92 tests API, chiffrement, TOTP, origines et documents publics réussis dans
  `mysold_publication_test`, base distincte des données locales et de production.
- 11 tests du système de publication Web et 3 tests Node du service worker réussis.
- Compilation Flutter Web release et validation de la configuration Nginx.
- Pages publiques et 404 : Playwright à 320, 390 et 1 440 px, thèmes clair/sombre,
  images chargées, pas de débordement horizontal, aucun stockage navigateur ni
  appel tiers automatique ; navigation HTML également vérifiée sans JavaScript.
- Contrastes calculés pour le texte principal, le texte secondaire et les liens
  du pied de page : au moins 4,5:1 dans les deux thèmes. Ce contrôle ponctuel ne
  remplace pas un audit WCAG complet.
- Liens externes du dépôt, de sa licence et de la démonstration : HTTP 200.
- Parcours réels de connexion et d’inscription dans le build release local :
  ouverture des notices dans un onglet sans accès à `window.opener`, maintien
  du formulaire initial et validation des champs obligatoires.
- Requêtes de lecture sur `https://mysold.ydoxide.fr/` : HTTPS 200, HTTP 301 vers
  HTTPS, CSP et HSTS présents au moment du contrôle. Le proxy émet également
  HSTS : sa duplication et la politique de sous-domaines sont à harmoniser côté proxy.

Les quatre suites Flutter destinées au navigateur n’ont pas pu démarrer : le
lanceur du SDK n’arrive pas à lancer Edge dans cet environnement. Ce n’est pas
un résultat de test fonctionnel de ces suites. Les contrôles Playwright utilisent
un navigateur Edge isolé lancé séparément.

L’analyseur signale sept avertissements/informations préexistants dans
`security_privacy_page.dart` (anciennes méthodes inutilisées et champ pouvant être
final). Ils n’ont pas été supprimés dans cet audit pour éviter une refonte de
l’import/export sans rapport avec la publication. Les autres fichiers Dart
analysés n’ont pas d’erreur signalée.

## Limites et actions d’exploitation

1. Les changements restent locaux tant qu’ils ne sont pas publiés et déployés.
2. L’exploitant officiel est `ydoxide` et le contact public fourni est le dépôt
   GitHub. Un canal confidentiel reste à prévoir pour les demandes personnelles
   et les signalements sensibles ; ne pas y publier de données d’utilisateur.
3. L’identité/adresse requise selon le statut de l’exploitant, l’hébergeur,
   la localisation des données et les durées réelles des journaux et sauvegardes
   doivent être renseignées. Les notices ne peuvent pas les déterminer seules.
4. Aucun port, pare-feu, certificat, contrat d’hébergement ou politique de purge
   de la VM n’a été modifié. Le port HTTP interne doit être réservé au reverse proxy.
5. Pas de mesure Lighthouse/Core Web Vitals ni de validation sur téléphone réel
   dans cet audit. Aucun score de vitesse ou de fluidité en production n’est annoncé.
6. L’indexation Google nécessite un déploiement, une vérification du domaine
   dans Search Console et une soumission du sitemap. Aucun délai ni rang garanti.
7. Un éventuel ajout de statistiques, CDN ou protection tiers par l’exploitant
   impose de réexaminer les données, cookies et mentions ; la configuration du
   reverse proxy ne peut pas être déduite entièrement de ce dépôt.

Le [guide de publication](../PUBLICATION.md) donne les variables et les étapes
de configuration, sans inclure de mot de passe ou de clé de production.
