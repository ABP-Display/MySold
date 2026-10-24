#!/bin/sh
# Explicit maintenance only. Normal installation/update never moves a database.
set -eu
umask 077
fail() { printf '%s\n' "MySold : $*" >&2; exit 1; }

# These modes run only in disposable PostgreSQL containers or docker compose exec.
case "${1:-}" in
  _copy)
    [ "${MYSOLD_STORAGE_TASK:-}" = 1 ] || fail 'Commande interne.'
    export LC_ALL=C
    [ -f /source/PG_VERSION ] || fail 'La source ne contient pas de base PostgreSQL.'
    [ "$(cat /source/PG_VERSION)" = "$PG_MAJOR" ] || fail 'Version PostgreSQL incompatible ; utiliser un export logique.'
    [ ! -e /source/postmaster.pid ] || fail 'Arrêter proprement la base source avant la copie.'
    state=$(pg_controldata /source | sed -n 's/^Database cluster state: *//p')
    [ "$state" = 'shut down' ] || fail 'La base source doit être arrêtée proprement.'
    [ ! -L /source/pg_wal ] || fail 'WAL externe : utiliser un export logique.'
    [ -z "$(find /source/pg_tblspc -mindepth 1 -maxdepth 1 -print -quit)" ] || fail 'Tablespaces externes : utiliser un export logique.'
    [ ! -L /destination/postgres ] || fail 'La destination ne doit pas être un lien.'
    if [ -e /destination/postgres ]; then
      [ -d /destination/postgres ] || fail 'Destination invalide.'
      [ -z "$(find /destination/postgres -mindepth 1 -maxdepth 1 -print -quit)" ] || fail 'Destination non vide : copie refusée.'
    fi
    stage=/destination/postgres.migrating
    [ ! -e "$stage" ] || fail 'Copie précédente incomplète : vérifier data/postgres.migrating. La source est intacte.'
    control=$(cksum /source/global/pg_control)
    mkdir "$stage"
    cp -a /source/. "$stage/"
    [ -f "$stage/global/pg_control" ] || fail 'Copie incomplète.'
    diff -qr /source "$stage" >/dev/null || fail 'La copie diffère de la source.'
    [ ! -e /source/postmaster.pid ] && [ "$control" = "$(cksum /source/global/pg_control)" ] || fail 'La source a changé pendant la copie.'
    if [ -d /destination/postgres ]; then rmdir /destination/postgres; fi
    mv "$stage" /destination/postgres
    printf '%s\n' 'Copie vérifiée ; volume source conservé intact.'
    exit 0
    ;;
  _dump)
    [ "${MYSOLD_STORAGE_TASK:-}" = 1 ] || fail 'Commande interne.'
    exec pg_dump --no-password -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom
    ;;
  _restore)
    [ "${MYSOLD_STORAGE_TASK:-}" = 1 ] || fail 'Commande interne.'
    objects=$(psql -X --no-password -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname !~ '^(pg_|information_schema$)') + (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname !~ '^(pg_|information_schema$)') + (SELECT count(*) FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE n.nspname !~ '^(pg_|information_schema$)') + (SELECT count(*) FROM pg_namespace WHERE nspname <> 'public' AND nspname !~ '^(pg_|information_schema$)')")
    [ "$objects" = 0 ] || fail 'Base destination non vide : restauration refusée.'
    exec pg_restore --no-password -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges --no-tablespaces --exit-on-error --single-transaction
    ;;
esac

case "${1:-}" in
  migrate|backup|restore) ;;
  *) printf '%s\n' 'Usage : sh scripts/data.sh migrate | backup | restore FICHIER.dump'; exit 1 ;;
esac

if [ "${1:-}" = restore ]; then
  [ "$#" -eq 2 ] && [ -f "$2" ] || fail 'Indiquer un fichier .dump existant.'
  exec 3< "$2"
fi
project_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
config="$project_dir/.env"
data_dir="$project_dir/data"
[ -f "$config" ] || fail 'Fichier .env manquant.'
cd "$project_dir"
maintenance_code=$(cat "$project_dir/scripts/data.sh")
compose() { docker compose --project-directory "$project_dir" --env-file "$config" -f "$project_dir/compose.yaml" "$@"; }
inside() { compose exec -T -e MYSOLD_STORAGE_TASK=1 db /bin/sh -c "$maintenance_code" -- "$@"; }
temporary=''
config_temporary=''
cleanup() {
  if [ -n "$temporary" ]; then rm -f "$temporary"; fi
  if [ -n "$config_temporary" ]; then rm -f "$config_temporary"; fi
}
trap cleanup 0
prepare_dirs() {
  mkdir -p "$data_dir/backups" "$data_dir/config"
  chmod 700 "$data_dir/backups" "$data_dir/config"
}
snapshot_config() {
  config_temporary=$(mktemp "$data_dir/config/.instance.env.XXXXXX")
  cat "$config" > "$config_temporary"
  chmod 600 "$config_temporary"
  mv "$config_temporary" "$data_dir/config/instance.env"
  config_temporary=''
}

case "$1" in
  migrate)
    [ ! -e "$data_dir/postgres.migrating" ] || fail 'Copie précédente incomplète dans data/postgres.migrating ; vérifier ce dossier avant de réessayer.'
    [ ! -L "$data_dir/postgres" ] || fail 'data/postgres ne doit pas être un lien.'
    if [ -e "$data_dir/postgres" ]; then
      [ -d "$data_dir/postgres" ] && [ -r "$data_dir/postgres" ] || fail 'Destination inaccessible ; exécuter avec sudo.'
      [ -z "$(find "$data_dir/postgres" -mindepth 1 -maxdepth 1 -print -quit)" ] || fail 'data/postgres non vide : migration refusée.'
    fi
    container=$(compose ps -aq db)
    if [ -z "$container" ]; then
      compose create --no-build db
      container=$(compose ps -aq db)
    fi
    [ -n "$container" ] || fail 'Conteneur PostgreSQL introuvable.'
    volume=$(docker inspect --format '{{range .Mounts}}{{if and (eq .Destination "/var/lib/postgresql/data") (eq .Type "volume")}}{{.Name}}{{end}}{{end}}' "$container")
    [ -n "$volume" ] || fail 'La base utilise déjà un dossier ou aucun ancien volume n’est monté.'
    image=$(docker inspect --format '{{.Config.Image}}' "$container")
    before=$(cksum "$config")
    prepare_dirs
    printf '%s\n' 'Arrêt des services pour une copie à froid…'
    compose stop --timeout 120
    docker run --rm --network none -e MYSOLD_STORAGE_TASK=1 \
      --mount "type=volume,source=$volume,target=/source,readonly" \
      --mount "type=bind,source=$data_dir,target=/destination" \
      --entrypoint /bin/sh "$image" -c "$maintenance_code" -- _copy
    [ "$before" = "$(cksum "$config")" ] || fail '.env a changé pendant la copie ; configuration conservée. Ne pas relancer une migration sur la destination déjà copiée.'
    config_temporary=$(mktemp "$project_dir/.env.migration.XXXXXX")
    awk '!/^[ \t]*(export[ \t]+)?POSTGRES_STORAGE[ \t]*=/ { print } END { print "POSTGRES_STORAGE=./data/postgres" }' "$config" > "$config_temporary"
    chmod 600 "$config_temporary"
    chown --reference="$config" "$config_temporary"
    mv "$config_temporary" "$config"
    config_temporary=''
    snapshot_config
    printf '%s\n' 'Migration terminée dans data/postgres. Ancien volume conservé.'
    printf '%s\n' 'Relancer : sudo docker compose --env-file .env up -d --build'
    ;;
  backup)
    prepare_dirs
    stamp=$(date -u +%Y%m%dT%H%M%SZ)
    temporary=$(mktemp "$data_dir/backups/.mysold-$stamp.XXXXXX")
    inside _dump > "$temporary"
    compose exec -T db pg_restore --list < "$temporary" >/dev/null
    result="$data_dir/backups/$(basename "$temporary" | sed 's/^\.//').dump"
    [ ! -e "$result" ] || fail 'Un export existe déjà sous ce nom.'
    chmod 600 "$temporary"
    snapshot_config
    mv "$temporary" "$result"
    temporary=''
    printf '%s\n' "Export terminé : $result"
    ;;
  restore)
    [ -z "$(compose ps -q api web)" ] || fail 'Restaurer sur une nouvelle instance avant de lancer l’API et le site.'
    compose up -d --wait --wait-timeout 120 db
    inside _restore <&3
    prepare_dirs
    snapshot_config
    printf '%s\n' 'Restauration terminée. Relancer : sudo docker compose --env-file .env up -d --build'
    ;;
esac
