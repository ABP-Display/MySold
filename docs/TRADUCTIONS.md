# Traductions de MySold

## Langue de l’interface

Six langues sont disponibles : français, anglais, espagnol, allemand, italien
et japonais. Le choix effectué dans les préférences s’applique immédiatement,
sans attendre la réponse du serveur. Il reste enregistré dans les préférences
locales et dans le profil utilisateur, avec les mécanismes existants.

L’application utilise uniquement des catalogues embarqués. Aucun service de
traduction distant n’est appelé pendant son utilisation. Les noms des comptes,
catégories, investissements, descriptions et autres données saisies par
l’utilisateur ne sont pas traduits.

## Organisation

- `frontend/lib/l10n/app_localizations.dart` : résolution des libellés,
  compatibilité avec les anciennes clés françaises sans accents et extension
  `context.tr()` / `context.trParams()`.
- `monthly_analytics_strings.dart` : statistiques mensuelles.
- `feature_strings.dart` : évolutions annuelles, simulations et libellés récents.
- `report_strings.dart` : libellés des rapports PDF.
- `completed_*.dart` : compléments des catalogues historiques, y compris les
  notices de confidentialité auto-hébergées. Ces compléments ont été préparés
  avec une aide de traduction automatique ; leur nuance rédactionnelle peut
  encore être affinée par des locuteurs natifs.

Les variantes d’accentuation des anciennes clés sont reconnues sans modifier
les valeurs métier stockées. Les paramètres utilisent des variables nommées,
par exemple `context.trParams('Année {count}', {'count': year})`. Les modèles
dynamiques existants sont compilés une seule fois, et non à chaque affichage.

## Rapports PDF

La génération reçoit explicitement la langue choisie. Les titres, légendes,
types d’opération, dates et nombres suivent cette langue. Une portée de langue
propre à chaque génération empêche deux exports simultanés de se mélanger.
Les données personnelles et les noms saisis restent intacts. Le format CSV de
sauvegarde n’est pas localisé : il reste stable pour la réimportation.

Deux variantes statiques de Noto Sans JP sont utilisées uniquement pour les
PDF japonais, car le moteur PDF ne rendait pas correctement le poids de la
police variable. La police originale de l’interface et sa licence OFL sont
conservées. `frontend/tool/make_report_fonts.py` permet de régénérer ces variantes
avec `fonttools`, outil de développement sans dépendance serveur.

## Contrôles

Depuis `frontend/`, lancer :

```powershell
flutter test test/localization_coverage_test.dart
```

Ce test vérifie la présence des traductions dans les cinq langues non françaises,
les appels explicites du code, la conservation des variables et l’absence de
texte visible écrit directement dans un widget `Text`, hors marque et valeurs
dynamiques. Cette couverture ne garantit pas, à elle seule, la qualité linguistique
de chaque phrase : les libellés construits indirectement et les nouveaux écrans
nécessitent également une vérification visuelle.

Les fixtures de navigateur dans `frontend/test/browser/` acceptent
`FIXTURE_LANG=de` ou `FIXTURE_LANG=ja` pour vérifier les écrans réels avec des
données fictives. `check_report_pdfs.py` vérifie le contenu des huit scénarios
de rapports français et japonais, dont janvier et les descriptions longues.

Les scripts de maintenance de catalogues sont réservés au développement.
`complete_catalog.py` peut envoyer des **libellés statiques uniquement** à un
service de traduction pour préparer des propositions. Ne jamais y inclure de
données utilisateur ni l’exécuter sur des exports personnels.

## Limites de périmètre

La vitrine HTML de `docs/` reste en français. Les détails techniques bruts reçus
du serveur peuvent conserver la langue du serveur ; leur libellé d’interface
est traduit, mais ils ne sont jamais envoyés à un traducteur externe. Les
documents juridiques traduits ne constituent pas une validation juridique.
