# GitHub Actions builds Flutter from these exact sources. This stage downloads
# the matching public release, including on a small VPS.
FROM python:3.13-slim AS release
ARG MYSOLD_REPOSITORY=ABP-Display/MySold
WORKDIR /source
COPY . .
RUN python tool/web_release.py fetch --repository "${MYSOLD_REPOSITORY}" --destination /site

FROM nginxinc/nginx-unprivileged:stable-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY nginx-tls.conf /etc/nginx/mysold-tls.conf
COPY --chmod=0755 nginx-tls-entrypoint.sh /docker-entrypoint.d/30-mysold-tls.sh
COPY --from=release /site /usr/share/nginx/html
EXPOSE 8080 8443
