#!/usr/bin/env bash
WAVE_DIR=$(realpath "${PWD}/../../../deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave")
export WAVE_DIR

export DOMAIN_NAME=dev.example.com

export "TRAEFIK_EMAIL=cert@${DOMAIN_NAME}"

if [[ -z ${CLOUDFLARE_API_TOKEN} ]]; then
  echo "Please enter the CLOUDFLARE_API_TOKEN or set the env variable: "
  read -r CLOUDFLARE_API_TOKEN
else
  echo "Read CLOUDFLARE_API_TOKEN from env"
fi

export CLOUDFLARE_API_TOKEN

export APP_NAME=HaakCo
export APP_ENV=local
export DB_HOST=postgres
export REDIS_PASS=null
export MAIL_USERNAME=""
export MAIL_PASSWORD=""
export MAIL_ENCRYPTION=null
export DB_NAME=db_example
export DB_USER=user_example
export DB_PASS=password_example
export APP_KEY=base64:8dQ7xw/kM9EYMV4cUkzKgET8jF4P0M0TOmmqN05RN2w=
export JWT_SECRET=Jrsweag3Mf0srOqDizRkhjWm5CEFcrBy

export TRUSTED_PROXIES='10.0.0.0/8,172.16.0.0./12,192.168.0.0/16'

export TRAEFIK_BASIC_USER="traefik"
export TRAEFIK_BASIC_PASSWORD_RAW='aitada1eeM6oomie1oog'
TRAEFIK_BASIC_PASSWORD_ENCODED=$(docker run --rm -ti xmartlabs/htpasswd "${TRAEFIK_BASIC_USER}" "${TRAEFIK_BASIC_PASSWORD_RAW}" | sed -E -e 's#.+\:(.+)#\1#' | xargs)
export TRAEFIK_BASIC_PASSWORD_ENCODED

docker-compose --project-name example up -d
