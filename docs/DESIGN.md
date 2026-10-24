# Interface MySold

La navigation et les composants communs suivent la sobriété de MyCopro :
titres hiérarchisés, surfaces délimitées, icônes simples et actions explicites.
Les six palettes MySold sont conservées, y compris le fond noir du thème Sombre.

- Ordinateur : navigation latérale et contenu limité à 1 280 pixels.
- Mobile et tablette : navigation basse ; les pages et les formulaires défilent.
- Les types d’opérations sont des filtres en haut du budget mensuel. Son
  graphique est repliable, fermé par défaut sur mobile.
- Les volets deviennent des fenêtres de 600 pixels maximum sur ordinateur et
  restent des panneaux inférieurs défilants sur mobile.
- Les couleurs des surfaces, bordures, champs et fenêtres viennent du thème.
  Les catégories gardent leur couleur dans les icônes des opérations.

Les montants des opérations occupent une colonne centrée verticalement à droite,
sur mobile et ordinateur. Les quatre types d’opérations ont la même largeur sur
PC et défilent horizontalement sur petit écran. Les sélecteurs de comptes,
catégories et investissements disposent d’une recherche, d’icônes et d’un repère
de sélection, dans une fenêtre sur ordinateur ou un volet sur mobile.

Les titres des pages utilisent une taille commune de 28 pixels sur mobile et
ordinateur, avec le même alignement à gauche et les mêmes espacements.
Les titres des pages secondaires peuvent revenir à la ligne et leur barre
de navigation adapte sa hauteur au texte, y compris avec un texte agrandi.
Dans le budget mensuel et la vue globale, le sélecteur est à droite du titre ;
le mois est abrégé sur petit écran. Si la largeur ou le texte agrandi ne permet
plus cette disposition, le sélecteur passe dessous, aligné à droite.
La page PIN garde son fond noir et le logo original : logo centré, titre dessous,
puis texte d’aide et espace de 32 pixels avant la saisie.
Les cadres d’information des graphiques en barres et de la répartition des
revenus sont affichés au-dessus de la zone visible du graphique. Ils restent
dans ses limites pendant un glissement, même lorsque les barres défilent
horizontalement, sans être découpés par le défilement ni déborder sur les panneaux voisins.
Le défilement vertical de la page reste possible depuis le graphique.

## Mode discret

Le bouton œil de la navigation masque ou réaffiche les montants. Le réglage
« Secouer pour cacher », dans Profil → Paramètres → Mode discret, est facultatif
et désactivé par défaut. Il est mémorisé sur cet appareil/navigateur.

L’activation vérifie la disponibilité du capteur et demande l’autorisation quand
le navigateur l’exige. Sur le Web, HTTPS (ou localhost) et un appareil compatible
sont nécessaires. La détection s’arrête lorsque l’option est désactivée ou que
la session est fermée. Une secousse masque uniquement : seul un geste
explicite sur le bouton œil ou le réglage réaffiche les montants.

## Revue des fonctions

La simulation comporte trois onglets de largeur égale couvrant toute la barre,
avec des libellés centrés : Budget, Investissement et Prêt. Seul
un appui sur leur titre change d’onglet ; les gestes horizontaux dans le contenu
ne déclenchent plus de changement de page. Les formulaires gardent leurs valeurs
et chaque onglet affiche une projection initiale, actualisable avec le bouton
« Calculer la simulation ». Un texte indique lorsque les paramètres ont changé.

Les projections Budget et Investissement partagent des courbes avec grille,
légendes, unités monétaires et infobulles contenues dans le graphique. Le budget
utilise les mois et les flux cumulés ; l’investissement utilise les années,
avec capitalisation et versements en fin de chaque période choisie.

Le prêt est à taux fixe nominal avec mensualités constantes. Le capital emprunté
est le montant total du projet moins l’apport. Les frais saisis sont payés au
départ et ne sont pas financés. L’assurance facultative est calculée sur le capital
initial. Le graphique en anneau détaille l’apport, le capital, les intérêts,
l’assurance et les frais. Le coût du crédit exclut l’apport et le capital ;
le total versé comprend le projet et le coût du crédit. Aucun frais implicite
n’est ajouté. Les calculs utilisent leur précision complète et l’affichage
arrondit au centime (hors arrondis contractuels des échéances bancaires).

Les comptes, catégories, investissements, budgets, simulations, exports, PIN,
MFA et mises à jour PWA restent disponibles. Aucun calcul financier n’est modifié.

Le réglage « Rappel mensuel » ne programmait aucune notification : il apparaît
désormais comme une fonction à venir, sans interrupteur donnant l’impression
qu’un rappel est actif. Les autorisations et alertes budgétaires existantes
restent accessibles.

## Vérifications de l’interface

Depuis `frontend/` :

```sh
flutter test test/workspace_design_test.dart test/privacy_provider_test.dart test/auth_layout_test.dart test/stamp_web_build_test.dart test/operation_controls_test.dart test/mobile_charts_test.dart test/page_headers_test.dart
flutter test test/simulation_projection_test.dart test/simulation_workspace_test.dart
node --test test/pwa_updates.test.cjs test/sw.test.cjs tool/privacy_gesture_test.cjs
```

La matrice des composants couvre les six thèmes, trois tailles d’écran et un
texte à 100 % / 200 %, ainsi que le défilement des fenêtres et le mode discret.
Les capteurs physiques doivent aussi être essayés sur les téléphones ciblés :
leur disponibilité dépend du matériel, du navigateur et des permissions.
