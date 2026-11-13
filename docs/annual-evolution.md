# Évolution annuelle

Accès : Profil > Évolution annuelle. Les trois onglets affichent les comptes, catégories et investissements, avec historique mensuel, référence au 1er janvier et variation. Le mode discret masque valeurs, pourcentages et graphiques.

## Données et cohérence

La structure existante est conservée. Deux collections de documents chiffrés sont ajoutées : `balanceEvents` (valeurs initiales et ajustements) et `annualReferences` (références explicites au 1er janvier). Elles suivent les données de l'utilisateur dans le CSV. Les imports désactivent la création automatique d'ajustements pour ne pas dupliquer leur historique.

Une correction de valeur est enregistrée après déduction des mouvements de transactions du même lot. Les comptes gérés par les actifs restent recalculés par le serveur. Le verrou utilisateur, le journal, les mutations et l'invalidation des synthèses participent à la même transaction PostgreSQL. Une requête répétée avec le même identifiant ne double pas les écritures.

`annual_analysis_cache` stocke une synthèse chiffrée par utilisateur et année, comprenant références et douze résumés mensuels par élément. Ce cache est dérivé, non exporté, et supprimé en cascade avec l'utilisateur. Il est invalidé après une mutation financière, puis reconstruit à la prochaine consultation. Les changements de profil ne l'invalident pas.

Cette première version privilégie la reconstruction fiable plutôt qu'un cumul incrémental complexe. Sur cache manquant, le serveur lit les mouvements depuis le début de l'année précédente (comparaison des catégories), y compris les années suivantes nécessaires pour remonter depuis la valeur actuelle. Les opérations antérieures ne sont pas déchiffrées. Le navigateur ne reçoit que les synthèses. Un changement rétroactif invalide toutes les années de cet utilisateur pour garantir la cohérence des clôtures suivantes.

Les périodes sont définies en UTC. Les mois futurs n'ont pas de clôture projetée. Une catégorie affiche un cumul de mouvements et non un patrimoine. La variation d'un investissement inclut les versements et retraits ; la variation de valorisation est présentée séparément, sans être assimilée à un taux de rendement financier.

## Historique préexistant

Les écritures anciennes ne permettent pas de retrouver des valorisations ou corrections jamais enregistrées. Les références reconstituées sont donc explicitement marquées à confirmer. Une référence manuelle, protégée par le PIN dans l'interface, ne modifie pas le solde courant. Si elle ne se réconcilie pas avec l'historique, l'écart est affiché et les clôtures historiques non démontrables ne sont pas tracées.

## Déploiement

Sauvegarder la base **et** `data/keys`, puis :

```sh
git pull --ff-only
docker compose up -d --build
```

Le serveur applique automatiquement la création du cache au démarrage. Aucune suppression ni migration des transactions existantes n'est requise. Il faut mettre à jour le frontend **et** l'API, pas seulement le service web.

## Vérifications

Tests backend dédiés : `python -m unittest test_annual_analysis`, exclusivement sur une base nommée `*_test`. Ils couvrent calcul en centimes sur 10 000 opérations, flux d'investissement et retraits, corrections manuelles, suppression rétroactive, cache chiffré, cloisonnement des utilisateurs, entrées invalides et protection CSRF. Les autres suites backend couvrent authentification, MFA et intégrité du chiffrement.

Les fixtures Chromium utilisent des données synthétiques et contrôlent le rendu à 320/390/1280 px ainsi que le défilement depuis une zone de graphique. Ces essais ne constituent pas une mesure de performance sur la VM Oracle à un cœur ni sur un téléphone physique ; ces deux environnements restent à vérifier après déploiement.

Les sources de tests restent versionnées. Seuls les résultats, captures, fichiers de couverture et sorties de debug sont ignorés par Git.

Validation du 13 novembre 2026 : 402 tests Flutter et 56 tests backend réussis ; compilation Web release réussie. Chromium : contrôles de rendu à 320, 390 et 1280 px, défilement depuis le graphique vérifié à 320 et 390 px. L'analyseur conserve 16 avertissements/info préexistants, sans nouvelle erreur.
