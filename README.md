# Stage 4: The different stages to learning how to deploy a Laravel App

## Intro

For this stage, we'll move to create docker containers. Having versioned containers makes it simpler, role forward and
backwards. It also gives us a way to test locally on a system that is close to production.

### Pros

* Very repeatable
* Faster from nothing to fully setup
* Can replicate the entire infrastructure for dev or staging.
* Everything documented.

### Cons

* Significantly more complicated.
* Takes longer initially to set up.
* Require knowledge for far more application and moving pieces.

## Assumptions

1. Php code is in git.
1. You are using PostgreSQL.
1. If not, replace the PostgreSQL step with your DB of choice.
1. You have a server.
1. In this example and future ones, we'll be deploying to [DigitalOcean](https://m.do.co/c/179a47e69ec8)
   but the steps should mostly work with any servers.
1. The server is running Ubuntu 20.04 or Kubernetes cluster.
1. You have SSH key pair.
1. Needed to log into your server securely.
1. You have a Domain Name, and you can add entries to point to the server.
1. We'll be using example.com here. Just replace that with your domain of choice.
1. For DNS, I'll be using [Cloudflare](https://www.cloudflare.com/) in these examples.
1. I would recommend using a DNS provider that supports [Terraform](https://www.terraform.io/) and
   [LetsEncrypt](https://community.letsencrypt.org/t/dns-providers-who-easily-integrate-with-lets-encrypt-dns-validation/86438)

## Steps 1: Build Docker Images

For things like the database and Redis, there is no need to build your own images as the stardard images on
https://hub.docker.com/ are perfect.

Though for things like PHP, I find it helps create your own image, so it has precisely what you want.

I cover the basics of what it does and how its setup in it's ReadMe if you would like to understand it better.

https://github.com/haakco/deploying-laravel-app-docker-ubuntu-php-lv

## Docker compose

To make things a bit simpler to manage and read I'll be using docker-compose files to set things up.

Let's first add the database.

We'll be using the default [PostgreSQL docker hub image](https://hub.docker.com/_/postgres), and we'll be using tag 13.

We are specifying a specific tag to prevent things breaking if the default version for Postgres increases. 

```yaml
version: '3.9'
services:
  pgmaster:
    image: postgres:13
    hostname: pgmaster.server
    restart: always
    environment:
      - "POSTGRES_DB=db_example"
      - "POSTGRES_USER=user_example"
      - "POSTGRES_PASSWORD=password_example"
    ports:
      - "5432:5432"
    volumes:
      - "db_pgmaster_vol:/var/lib/postgresql/data"
volumes:
  db_pgmaster_vol: {}
```

Next we want to add our

```shell
git clone https://github.com/thedevdojo/wave ./wave
```

```shell
docker-compose --project-name example up -d
```

```shell
docker-compose --project-name example down --remove-orphan
```

