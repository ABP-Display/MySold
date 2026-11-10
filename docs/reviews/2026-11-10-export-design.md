# Revue technique et design MySold

Revue du 10 novembre 2026. Périmètre : export PDF, états de chargement et navigation secondaire. Ce document ne constitue pas un audit complet de sécurité ou de toute l'application.

## Défaut reproduit et corrigé

Un janvier synthétique de 183 opérations, dont 180 dépenses, reproduisait une boucle de pagination. La version avec assertions signalait « more than 20 pages ». Le contrôle interne du package PDF étant une assertion, il ne protégeait pas la compilation de production contre cette boucle.

La cause n'était pas une règle spéciale du calendrier de janvier : les tableaux étaient imbriqués dans des conteneurs non paginables, eux-mêmes dans une colonne. Un groupe trop haut ne pouvait jamais avancer à la page suivante. Sans les données du compte concerné, cela reproduit un défaut correspondant aux symptômes, mais ne prouve pas que ce soit l'unique cause possible de son incident.

Corrections appliquées : tableaux directement accessibles au moteur de pagination, en-têtes répétés, découpage des textes longs en lignes de continuation sans suppression de caractères, et limite de 250 pages vérifiée également en production. Au-delà, une erreur invite à réduire la période au lieu de poursuivre la génération indéfiniment.

## Revue ECC du correctif

Référentiel consulté : [ECC, agent code-reviewer](https://github.com/affaan-m/ECC/blob/main/agents/code-reviewer.md). Ses consignes ont été appliquées manuellement au diff et aux appels concernés ; aucun moteur Claude, plugin ECC ou script d'installation distant n'a été exécuté.

Contrôles : régression de pagination reproduite avant le correctif, conservation du texte et des montants, erreurs récupérées par l'écran d'export, absence de modification des données utilisateur ou du backend, et couverture des entrées longues. Les tableaux restent des éléments PDF textuels : aucune exécution du contenu importé n'est introduite.

| Sévérité ECC | Constats nouveaux dans le correctif | État |
| --- | --- | --- |
| CRITICAL | 0 | pass |
| HIGH | 0 | pass |
| MEDIUM | 0 | pass |
| LOW | 0 | pass |

Verdict : **APPROVE** pour le correctif, dans le périmètre vérifié. La limite de 250 pages est inspectée dans le code, mais un rapport dépassant cette limite n'a pas été généré pendant les tests.

## Revue Design et Risques Existants

Les propositions ci-dessous ne sont pas des changements déjà appliqués.

| Priorité | Avant | Après proposé | Pourquoi / référence |
| --- | --- | --- | --- |
| P2 | `compute()` est présenté comme une génération en arrière-plan. Sur Flutter Web, il appelle le traitement sur le même thread. | Utiliser un véritable Web Worker ou une génération serveur, avec une progression mesurée. | La pagination est réparée, mais un très gros rapport peut encore provoquer une pause de l'interface. `frontend/lib/services/transaction_export_service.dart:106`. L'implémentation Web du SDK installé a été lue pour vérifier ce comportement. |
| P2 | En cas d'erreur, la barre de progression devient indéterminée alors que le travail a échoué. | Arrêter ou masquer la barre et privilégier un état d'erreur fixe avec une action claire. | Une animation de travail en cours contredit le message d'échec. `frontend/lib/screens/profile/export_report_page.dart:392`. |
| P2 | Sur mobile, le menu des investissements affiche seulement une partie de ses six choix, sans indicateur de défilement. | Ajouter un indice de débordement accessible, par exemple une flèche contextuelle ou une barre de défilement. | Certains types peuvent paraître absents lorsque trois choix occupent exactement la largeur. `frontend/lib/widgets/app_page_tab_menu.dart:118`. |
| P3 | Des libellés français de l'export restent sans accents : « Periode », « Annee complete », « Generer le PDF ». | Corriger les libellés affichés tout en conservant les correspondances des clés de traduction historiques. | Améliorer la finition sans casser les autres langues. `frontend/lib/screens/profile/export_report_page.dart:124`, `:128`, `:210`. |

## Méthode

- Lecture de l'implémentation et du moteur de pagination PDF réellement installé.
- Reproduction avant correction avec assertions, puis essais de la compilation Web release dans Chromium.
- Données exclusivement synthétiques : janvier et février chargés, mois simple, année, période vide, journée unique, reste négatif et description très longue.
- Extraction du texte des PDF pour vérifier la conservation des opérations et de la description complète, puis contrôle visuel de pages rendues en images.
- Revue design fondée sur les instructions installées `emil-design-eng` et les principes de `animation-performance`, adaptés à Flutter plutôt qu'appliqués mécaniquement comme du CSS.
- Résultats : 402 tests Flutter réussis sur la version finale, dont les tests ciblés de texte et de périodes. Compilation Web release réussie. Les 16 avertissements/info de l'analyseur étaient déjà présents.
- Conservation vérifiée par extraction : les 180 identifiants de dépenses de chacun des rapports janvier/février sont présents ; les 100 paragraphes et les marqueurs de début et de fin de la description longue sont présents.

Les performances sur un téléphone réel et la cause exacte liée aux données privées du compte restent à confirmer. Les recommandations de design et les risques préexistants ci-dessus ne sont pas présentés comme des régressions introduites par ce correctif.
