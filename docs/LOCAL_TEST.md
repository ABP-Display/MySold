# Instance de test locale

Cette configuration ne remplace pas `compose.yaml` et ne publie rien sur GitHub.
Elle utilise le projet Docker `mysold-local`, des volumes PostgreSQL et de clés
distincts, et écoute uniquement sur `http://localhost:28086`.
Elle ne lit pas le fichier `.env` de production : son mot de passe PostgreSQL est
généré dans `.env.local`, déjà exclu de Git.

Depuis le dossier MySold, avec Docker Desktop et Flutter disponibles :

```powershell
./tool/start-local.ps1
python tool/seed_local_demo.py
```

Le second script est facultatif. Il crée un compte et des opérations fictives
pour visualiser les quatre graphiques. Il est limité à `localhost:28086`.

- E-mail : `demo@mysold.local`
- Mot de passe de démonstration : `MySold-local-2026!`
- PIN : `123456`

Après une modification du code Flutter, relancer `./tool/start-local.ps1` pour
recompiler et mettre à jour l'aperçu. Le conteneur Nginx sert le dossier local
`frontend/build/web` en lecture seule. Le script actualise aussi la version PWA.
Les données de test sont conservées lors des redémarrages.

Pour arrêter uniquement cette instance, sans effacer ses données :

```powershell
docker compose --project-name mysold-local --env-file .env.local -f compose.local.yaml down
```

Ne pas réutiliser les identifiants de démonstration pour un déploiement public.
