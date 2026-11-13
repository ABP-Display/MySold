# Démonstration statique MySold

Pour installer l’application complète sur un serveur, suivre le
[guide d’installation Docker](INSTALLATION.md). Les instructions ci-dessous
concernent uniquement la vitrine de démonstration. Le [guide des données](DONNEES.md)
décrit les sauvegardes et le déplacement d’une instance.
Le [guide des traductions](TRADUCTIONS.md) décrit la langue de l’application
complète, indépendamment de cette vitrine.

Ouvrir `index.html` dans un navigateur. Aucun serveur applicatif, compilation
Flutter, conteneur Docker ou base de données n’est nécessaire pour cette vitrine.
Les fichiers et ressources sont tous locaux et utilisent des chemins relatifs,
compatibles avec une publication dans le sous-dossier d’un site.

La démo reprend les vues Mois, Stats mensuelles, Stats annuelles et Profil,
ainsi que la gestion des comptes, catégories, investissements, simulations,
évolutions annuelles et l’aperçu des rapports. Sur mobile, la navigation et les
sélecteurs de section flottent en bas de l’écran, comme dans la PWA actuelle.
Le bouton de sortie du mode discret apparaît en superposition, sans déplacer
le contenu. Les menus gardent leur fond opaque.

Elle utilise un jeu de données
entièrement fictif, arrêté au 22 octobre 2026. Elle est indépendante de l’instance
MySold et de son API : aucune connexion, création de compte ou écriture n’est
possible. Les noms, comptes, opérations et montants sont des exemples intégrés
au JavaScript, jamais des données exportées d’un utilisateur.

Les onglets, types d’opération, détails, recherche, thèmes et mode discret
fonctionnent pour présenter l’interface. Les changements sont uniquement en
mémoire et disparaissent au rechargement. La démo ne crée ni cookie, ni
localStorage, ni IndexedDB, ni service worker. Elle n’appelle aucune API et
n’intègre aucun outil de suivi. Les éventuels journaux techniques de l’hébergeur
restent indépendants de ces fichiers.

La simulation utilise des calculs d’exemple en mémoire. Le rapport affiche un
aperçu fictif, sans téléchargement PDF ni import/export de données réelles.
Cette vitrine reste en français ; le choix de langue de l’application complète
est indépendant.

## Vérification de la démo

`node docs/demo_test.cjs http://127.0.0.1:9235` vérifie les dix vues aux largeurs
320, 390 et 1 280 px, l’absence de stockage navigateur, les thèmes et le mode
discret. Cette commande nécessite un navigateur Chromium de test avec son port
de débogage ouvert. Les captures sont écrites dans `test-results/`.

## GitHub Pages

Après publication des fichiers dans le dépôt, sélectionner dans ses paramètres :
**Pages → Deploy from a branch → main → /docs**. Le site de démo sera servi
séparément du déploiement Docker. Aucune publication automatique n’est configurée.

La page fonctionne également comme un simple fichier HTML local.

Le code et les ressources propres à MySold restent soumis à la licence du dépôt.
Roboto et Material Icons conservent leurs licences tierces, précisées dans
`assets/NOTICE.txt` et `assets/Apache-2.0.txt`.
