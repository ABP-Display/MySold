# GitHub Actions builds Flutter from these exact sources. This stage downloads
# the matching public release, including on a small VPS.
FROM python:3.13-slim AS release
ARG MYSOLD_REPOSITORY=ABP-Display/MySold
WORKDIR /source
COPY . .
RUN python tool/web_release.py fetch --repository "${MYSOLD_REPOSITORY}" --destination /site

FROM nginxinc/nginx-unprivileged:stable-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=release /site /usr/share/nginx/html
EXPOSE 8080
