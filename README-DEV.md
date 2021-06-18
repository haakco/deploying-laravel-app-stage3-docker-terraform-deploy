## Local Dev enviroment

We'll start by setting up a local development enviroment.

To make life simpler please add the following DNS entries to your DNS server pointing them at ```127.0.0.1```.

* ```*.dev.example.com```
* ```dev.example.com```

This will allow you to use any url in the ```dev.example.com``` for local development without having to create specific
entries for each end point.

For the production enviroment we'll be reusing most of the code we create for Dev.

The only thing I would suggest you also look into if you are on Windows or Mac is https://mutagen.io/.

This can make quiet a big difference in the speed of your running containers.

I'll be using docker-compose files to set run everything. This just makes things a bit simpler.

All the file can be found at [./infra/local_dev](./infra/local_dev)

The complete compose file is here [./infra/local_dev/docker-compose.yml](./infra/local_dev/docker-compose.yml)

We'll be passing most of the configuration via environmental variable.

These are set via [```runDev.sh```](./infra/local_dev/runDev.sh).

### Proxy

To make things simpler with docker we'll be adding Traefik to handle SSL cert generation, via LetsEncrypt, and to route
the relevant URL to the correct docker container.

We'll also be using it to handle basic auth for any of our applications that don't have auth built in.

```yaml
  traefik:
    image: "traefik:v2.4"
    container_name: "traefik"
    hostname: traefik.server
    environment:
      - "CF_DNS_API_TOKEN=${CLOUDFLARE_API_TOKEN}"
      - "CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}"
    command:
      #- "--log.level=DEBUG"
      - "--api"
      - "--api.insecure=true"
      - "--providers.docker.endpoint=unix:///var/run/docker.sock"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entryPoint.scheme=https"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.le.acme.email=${TRAEFIK_EMAIL}"
      - "--certificatesresolvers.le.acme.dnschallenge=true"
      - "--certificatesresolvers.le.acme.dnschallenge.provider=cloudflare"
      - "--certificatesresolvers.le.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53,1.0.0.1:53"
      - "--certificatesresolvers.le.acme.dnschallenge.delaybeforecheck=20"
      - "--certificatesresolvers.le.acme.storage=/data/acme.json"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.$DOMAIN_NAME`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.tls.certresolver=le"
      - "traefik.http.routers.traefik.middlewares=traefik-auth, traefik-compress"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=${TRAEFIK_BASIC_USER}:${TRAEFIK_BASIC_PASSWORD_ENCODED}"
      - "traefik.http.middlewares.traefik-compress.compress=true"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "${PWD}/traefik:/data"
```

All traefik to port 80 and 443 will be directed to traefik.

It will then route any traefik to the relevant container.

You'll also see that the config contains the CloudFlare Api Token we've generated previously.

This is to allow traefik to generate certificates via the DNS method.

This tends to simplify some things as we can generate the certs before everything is up, and it allows us to generate
wildcard certificates if we want.

We pass this in via the environmental variable ```${CLOUDFLARE_API_TOKEN}```. We also pass an email that LetsEncrypt
will use to notify on ```${TRAEFIK_EMAIL}```.

Traefik is also configured to auto redirect http to https.

By default, Traefik is configured to not route any traffic. Rather it will watch the container labels to see what it
must do.

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.traefik.rule=Host(`traefik.$DOMAIN_NAME`)"
```

Here you can see the labels we have for the traefik container.

We first tell traefik we want it enabled for this container.

Next we say we want to route the URL traefik.$DOMAIN_NAME (This becomes traefik.example.com) to the traefik container.

```yaml
        - "traefik.http.routers.traefik.entrypoints=websecure"
        - "traefik.http.routers.traefik.service=api@internal"
```

We next say we want to route https traefik to the traefik dashboard.

Next we ask traefik to generate an SSL certificate via LetsEncrypt

```yaml
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.tls.certresolver=le"
```

Finally, we enable compression and basic auth for the dashboard.

```yaml
      - "traefik.http.routers.traefik.middlewares=traefik-auth, traefik-compress"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=${TRAEFIK_BASIC_USER}:${TRAEFIK_BASIC_PASSWORD_ENCODED}"
      - "traefik.http.middlewares.traefik-compress.compress=true"
```

The auth password needs to be encrypts via htpasswd.

Bellow is the script used in the runDev.sh to generate the encrypted password.

```shell
export TRAEFIK_BASIC_USER="traefik"
export TRAEFIK_BASIC_PASSWORD_RAW='aitada1eeM6oomie1oog'
TRAEFIK_BASIC_PASSWORD_ENCODED=$(docker run --rm -ti xmartlabs/htpasswd "${TRAEFIK_BASIC_USER}" "${TRAEFIK_BASIC_PASSWORD_RAW}" | sed -E -e 's#.+\:(.+)#\1#' | xargs)
export TRAEFIK_BASIC_PASSWORD_ENCODED
```

To summarise the labels it will make it that https://traefik.example.com is routed to the traefik dashboard, and the
user will be prompted for the basic auth credentials before allowing access.

### Database

Next we add the database.

We'll be using the default [PostgreSQL docker hub image](https://hub.docker.com/_/postgres), and we'll be locking our
version down so that if there is a new release our DB doesn't break, but we'll still get updates for the same version.

At this time the latest version is 13, so we'll be using tag ```:13```.

```yaml
  postgres:
    image: postgres:13
    container_name: "postgres"
    hostname: pg.server
    restart: always
    environment:
      - "POSTGRES_DB=$DB_NAME"
      - "POSTGRES_USER=$DB_USER"
      - "POSTGRES_PASSWORD=$DB_PASS"
    ports:
      - "5432:5432"
    volumes:
      - "postgres_vol:/var/lib/postgresql/data"
  volumes:
    db_pgmaster_vol: { }
```

We use environmental variables to set the database name, user and password.

We also tell docker we want the database to be external visible on port 5432.

***(!! Do not expose this port in Production.)***

We also create a volume to store the data.

Just be carefully if you delete this volume you will delete the all the data.

### Redis

Next we want to add redis at the same time we'll be
adding [redis commander](https://github.com/joeferner/redis-commander)
to give use a basic admin interface.

```yaml
  redis:
    image: redis
    container_name: "redis"
    hostname: redis.server
    restart: always
    command: [
        "redis-server",
        "--appendonly yes",
    ]
    ports:
      - "6379:6379"
    volumes:
      - "db_redis_vol:/data"
  rediscommander:
    image: rediscommander/redis-commander:latest
    container_name: "rediscommander"
    hostname: rediscommander.server
    environment:
      - "REDIS_HOSTS=lvredis:redis.server:6379"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.redis-commander.rule=Host(`rediscommander.$DOMAIN_NAME`)"
      - "traefik.http.routers.redis-commander.entrypoints=websecure"
      - "traefik.http.services.redis-commander.loadbalancer.server.port=8081"
      - "traefik.http.routers.redis-commander.tls=true"
      - "traefik.http.routers.redis-commander.tls.certresolver=le"
      - "traefik.http.routers.redis-commander.middlewares=redis-commander-auth, redis-commander-compress"
      - "traefik.http.middlewares.redis-commander-auth.basicauth.users=${TRAEFIK_BASIC_USER}:${TRAEFIK_BASIC_PASSWORD_ENCODED}"
      - "traefik.http.middlewares.redis-commander-compress.compress=true"
    volumes
  db_redis_vol: { }
```

Once again we make Redis accessible externally.

```yaml
    ports:
      - "6379:6379"
```

We then also let traefik know that we want the ```rediscommander.$DOMAIN_NAME``` to be routed to the redis commander
container.

```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.redis-commander.rule=Host(`rediscommander.$DOMAIN_NAME`)"
      - "traefik.http.routers.redis-commander.entrypoints=websecure"
      - "traefik.http.services.redis-commander.loadbalancer.server.port=8081"
      - "traefik.http.routers.redis-commander.tls=true"
      - "traefik.http.routers.redis-commander.tls.certresolver=le"
      - "traefik.http.routers.redis-commander.middlewares=redis-commander-auth, redis-commander-compress"
      - "traefik.http.middlewares.redis-commander-auth.basicauth.users=${TRAEFIK_BASIC_USER}:${TRAEFIK_BASIC_PASSWORD_ENCODED}"
      - "traefik.http.middlewares.redis-commander-compress.compress=true"
```

### Wave App

Finally, we do the Laravel application.

We are using the image created previously ```haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv```.

```yaml
website:
  image: haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv
  container_name: "web"
  hostname: web.server
  restart: always
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.website.rule=Host(`$DOMAIN_NAME`,`www.$DOMAIN_NAME`)"
    - "traefik.http.routers.website.entrypoints=websecure"
    - "traefik.http.routers.website.tls=true"
    - "traefik.http.routers.website.tls.certresolver=le"
    - "traefik.http.routers.website.middlewares=website-compress"
    - "traefik.http.middlewares.website-compress.compress=true"
  environment:
    - ENABLE_HORIZON=FALSE
    - CRONTAB_ACTIVE=TRUE
    - GEN_LV_ENV=TRUE
    - LVENV_APP_NAME=$APP_NAME
    - LVENV_APP_ENV=$APP_ENV
    - LVENV_APP_KEY=$APP_KEY
    - LVENV_APP_DEBUG=true
    - LVENV_APP_LOG_LEVEL=debug
    - LVENV_APP_URL=https://$DOMAIN_NAME
    - LVENV_DB_CONNECTION=pgsql
    - LVENV_DB_HOST=$DB_HOST
    - LVENV_DB_PORT=5432
    - LVENV_DB_DATABASE=$DB_NAME
    - LVENV_DB_USERNAME=$DB_USER
    - LVENV_DB_PASSWORD=$DB_PASS
    - LVENV_BROADCAST_DRIVER=log
    - LVENV_CACHE_DRIVER=redis
    - LVENV_SESSION_DRIVER=redis
    - LVENV_SESSION_LIFETIME=9999
    - LVENV_QUEUE_DRIVER=redis
    - LVENV_REDIS_HOST=$REDIS_HOST
    - LVENV_REDIS_PASSWORD=$REDIS_PASS
    - LVENV_REDIS_PORT=6379
    - LVENV_MAIL_DRIVER=smtp
    - LVENV_MAIL_HOST=smtp.mailtrap.io
    - LVENV_MAIL_PORT=2525
    - LVENV_MAIL_USERNAME=$MAIL_USERNAME
    - LVENV_MAIL_PASSWORD=$MAIL_PASSWORD
    - LVENV_MAIL_ENCRYPTION=$MAIL_ENCRYPTION
    - LVENV_PUSHER_APP_ID=
    - LVENV_PUSHER_APP_KEY=
    - LVENV_PUSHER_APP_SECRET=
    - LVENV_REDIS_CLIENT=phpredis
    - LVENV_JWT_SECRET=$JWT_SECRET
    - LVENV_PADDLE_VENDOR_ID=
    - LVENV_PADDLE_VENDOR_AUTH_CODE=
    - LVENV_PADDLE_ENV=sandbox
    - LVENV_WAVE_DOCS=true
    - LVENV_WAVE_DEMO=true
    - LVENV_WAVE_BAR=true
    - LVENV_TRUSTED_PROXIES=$TRUSTED_PROXIES
    - LVENV_ASSET_URL=' '
  volumes:
    - "$WAVE_DIR:/var/www/site"
```

As mentioned this image doesn't hold the Laravel code.

So to get that in the container we first checkout the git repository

```shell
git clone https://github.com/haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave
```

We then add this directory as a volume for the container.

```yaml
volumes:
  - "$WAVE_DIR:/var/www/site"
```

We put the local path in the ```WAVE_DIR``` environmental variable.

This allows us to edit the files locally but test via an enviroment that is as close as possible to production.

Once again we have the URL ```$DOMAIN_NAME``` routed into the container and certs generated vie Traefik.

Finally, we configure how we want the container to run, and the setting for the .env file via the environmental
variables.

Please see https://github.com/haakco/deploying-laravel-app-docker-ubuntu-php-lv to see what all the variables do.

### Running Dev Enviroment

Ok we are now ready to run the Dev enviroment.

To make your life simple I've created a script.

```shell
runDev.sh
```

Just alter the environmental variables for you specific setting and then run.

It should spin up a complete enviroment for you.

I've all so added some more scripts to make your life simpler.

```enterWeb.sh``` Will do and exec into the running Laravel container as the web user.

This can be used to do things like run composer installs or any artisan commands.

If you need root access you can rather use ```enterWebRoot.sh```.

Finally, there is the ```stopDev.sh``` to stop everything.
