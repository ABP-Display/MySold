#!/bin/sh
set -eu

case "${TLS_ENABLED:-false}" in
    false)
        rm -f /tmp/mysold-tls/https.conf
        ;;
    true)
        for file in fullchain.pem privkey.pem; do
            path="/etc/nginx/mysold-certs/$file"
            if [ ! -f "$path" ] || [ ! -r "$path" ] || [ ! -s "$path" ]; then
                printf 'MySold TLS: %s is missing, empty or unreadable. Check TLS_CERTS_DIR and TLS_CERT_GID.\n' "$file" >&2
                exit 1
            fi
        done
        mkdir -p /tmp/mysold-tls
        ln -sf /etc/nginx/mysold-tls.conf /tmp/mysold-tls/https.conf
        ;;
    *)
        printf 'MySold TLS: TLS_ENABLED must be true or false.\n' >&2
        exit 1
        ;;
esac
