# Présentation de MySold

[MySold sur GitHub Pages](https://abp-display.github.io/MySold/) présente
l’application et ses fonctionnalités à partir de captures de l’interface
Flutter Web locale. Elles utilisent des comptes et opérations fictifs.

`index.html` est la version statique de la page d’accueil officielle. Elle
fonctionne sans JavaScript, API, connexion ni stockage navigateur. Le bouton
« Accéder à l’application » ouvre la connexion sur l’instance officielle.
Il ne s’agit pas d’une démo interactive.

## Publier et mettre à jour

Dans GitHub : **Settings → Pages → Deploy from a branch → main → /docs**.
La page utilise des chemins relatifs pour ses ressources et reste
`noindex`, avec le [site officiel](https://mysold.ydoxide.fr/) comme canonique.

La source commune se trouve dans `backend/templates/public/discover.html`.
Les captures compressées et la feuille de style sont dans
`backend/public_assets/`. Après modification, régénérer la copie statique
depuis la racine du dépôt, dans un environnement Python disposant des
dépendances de `backend/requirements.txt` :

```sh
python backend/generate_showcase.py
python backend/generate_showcase.py --check
```

La génération ne contacte ni la base ni l’instance de production.
Pour remplacer les captures, utiliser exclusivement un compte local de test
rempli de données fictives. Ne pas publier une capture issue d’un compte réel.
Le script `frontend/tool/compress_public_preview.py` (avec Pillow) produit les
versions WebP bureau et mobile ainsi que l’aperçu social à partir des PNG
`gallery-{expenses,income,monthly,year}[-mobile].png`.

## Guides

- [Installation Docker](INSTALLATION.md)
- [Publication et référencement](PUBLICATION.md)
- [Sauvegardes et restauration](DONNEES.md)
- [Traductions](TRADUCTIONS.md)
