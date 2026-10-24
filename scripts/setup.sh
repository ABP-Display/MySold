#!/bin/sh
# Configure an Ubuntu/Linux installation without Node.js. Never rotate secrets.
set -eu
project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
target="$project_dir/.env"

if [ -e "$target" ]; then
  if awk '
    /^[ \t]*(export[ \t]+)?POSTGRES_PASSWORD[ \t]*=/ {
      sub(/^[ \t]*(export[ \t]+)?POSTGRES_PASSWORD[ \t]*=[ \t]*/, "")
      sub(/[ \t\r]+$/, "")
      quote = substr($0, 1, 1)
      if (quote == "\"" || quote == sprintf("%c", 39)) {
        value = substr($0, 2)
        end = index(value, quote)
        if (end == 0) exit
        value = substr(value, 1, end - 1)
      } else {
        sub(/[ \t]+#.*/, "")
        sub(/[ \t]+$/, "")
        value = $0
      }
      valid = length(value) > 0 && value != "REPLACE_WITH_A_RANDOM_PASSWORD" && substr(value, 1, 1) != "#"
      exit
    }
    END { exit !valid }
  ' "$target"; then
    printf '%s\n' '.env déjà présent ; configuration et secret conservés.'
    exit 0
  fi
  printf '%s\n' '.env existe mais POSTGRES_PASSWORD est absent, vide ou non configuré.' >&2
  printf '%s\n' 'Restaurez le secret de votre base existante ; pour une installation neuve, renseignez un secret aléatoire fort. Aucun fichier modifié.' >&2
  exit 1
fi

secret=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
if [ "${#secret}" -ne 64 ]; then
  printf '%s\n' 'Impossible de générer un secret aléatoire.' >&2
  exit 1
fi
umask 077
# noclobber also protects against another setup creating .env concurrently.
if (set -C; sed "s/REPLACE_WITH_A_RANDOM_PASSWORD/$secret/" "$project_dir/.env.example" > "$target"); then
  printf '%s\n' '.env créé avec un secret aléatoire. Renseignez APP_ORIGIN et COOKIE_SECURE pour votre domaine.'
else
  printf '%s\n' 'Création de .env impossible. Vérifiez les droits du dossier ; aucune configuration existante ne sera écrasée.' >&2
  exit 1
fi
