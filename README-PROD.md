## Production enviroment

The production environment is basically going to be a merging of the Dev enviroment with the Packer, Ansible and
Terraform from the previous steps.

### Docker image with code

The first big difference is going to be creating a docker image with the Laravel code inside.

To do this I've created a git repository which is basically a clone of the Wave project with one or two minor changes.

* https://github.com/haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave

I've then gone and added
a [Dockerfile](https://github.com/haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave/blob/main/Dockerfile).

This image is then built
on [Docker Hub](https://hub.docker.com/repository/docker/haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave)

* https://hub.docker.com/repository/docker/haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave

If you would like to build it locally I've added a script file to make it easier.

* https://github.com/haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv-wave/blob/main/buildDocker.sh

Here's the Dockerfile

```dockerfile
  
FROM haakco/deploying-laravel-app-ubuntu-20.04-php7.4-lv

USER www-data

## Cleanout previous dev just in case
RUN rm -rf /var/www/site/*

ADD --chown=www-data:www-data . /var/www/site

WORKDIR /var/www/site

RUN composer install --no-ansi --no-suggest --no-scripts --prefer-dist --no-progress --no-interaction \
      --optimize-autoloader

USER root

RUN find /usr/share/GeoIP -not -user www-data -execdir chown "www-data:" {} \+ && \
    find /var/www/site -not -user www-data -execdir chown "www-data:" {} \+
```

It's simply starting with the php [Docker image](https://github.com/haakco/deploying-laravel-app-docker-ubuntu-php-lv)
we created previously.

We then add the Laravel code to ```/var/www/site``` and do a composer install.

That's all that's needed.

You now have a docker image that is versioned to your code.

### DNS and Server setup

This step mirror the Stage 3 step very closely, so I'm not going to go into to much detail.

The big changes are that we now install docker via Ansible, and we add a composer file in the ```docker_deploy``` role.

We are also not using Digital Oceans DB or Redis but the docker versions.

I've done this more to show you how to do all the different options.

Though I would recommend that you rather use Digital Oceans DB and Redis.

Mainly as it just reduces the amount of things you will need to manage.

Another change from the local dev is that we'll be mounting in directories rather than creating volumes. Then main
reason is that it reduces the chance of you accidentally deleting your db.

I know more than one person who ran a volume prune or volume rm with out thinking and accidentally removed there DB
files.

#### docker_deploy Task

Bellow is the ```docker_deploy``` task.

It basically makes sure the directories that will be mounted in exist, copies the copose file over and adds an entry to
cron to run the compose file on every reboot.

This is to just make sure that on a reboot it will go back into a working state.

Please alter
the [./infra/ansible/roles/docker_deploy/files/remote_docker_prod/runProd.sh](./infra/ansible/roles/docker_deploy/files/remote_docker_prod/runProd.sh)
and set the environmental variable to what you would like.

```yaml
---
- name: Make sure the docker PostgresSQL dir exists
  ansible.builtin.file:
    path: /docker/postgres
    state: directory
    recurse: yes
    owner: 999
    group: 999

- name: Make sure the docker Redis dir exists
  ansible.builtin.file:
    path: /docker/redis
    state: directory
    recurse: yes
    owner: 999
    group: 999

- name: Make sure the docker Redis dir exists
  ansible.builtin.file:
    path: /docker/traefik
    state: directory
    recurse: yes
    owner: 999
    group: 999

- name: Sync docker directory to remote
  synchronize:
    src: remote_docker_prod
    dest: /root/
    delete: yes
    recursive: yes

- name: Start production docker on reboot
  cron:
    name: "Start production docker on reboot"
    special_time: reboot
    state: present
    job: '/root/remote_docker_prod/runProd.sh 2>&1 | /usr/bin/logger -t DOCKER_START'
```

### Packer

Once again we are going to create a digital ocean server image using packer and ansible.

Nothing is different from the Stage 3 process.

Once you have the new image snap shot name.

Please update the ```base_web_snapshot_name``` variable in the terraform
file [./infra/terraform/variables.tf](./infra/terraform/variables.tf).

#### Terraform apply

Now just check over all the terraform variable files and make any alterations that you would like.

Once you've gone through the terraform files and altered the variable to your local enviroment.

Remember to then set the CLOUDFLARE_API_TOKEN and DIGITALOCEAN_TOKEN environmental variables.

I would recommend using the script provided in Stage 3 to make your life simpler.

Then run the ```terraform init```.

It will prompt you if you forgot.

You can then run the ```./apply.sh```.

This should spin up a server in based on the packer image we created.

As it boots up it should auto start the production enviroment via the cron command added.

### Run migrations

Ok now the finall step needed is to run the migrations and seed.

Just ssh into the server and then go to the ```/root/remote_docker_prod/``` directory.

Run

```shell
./enterWeb.sh
```

This will put your in the docker container.

Now you just need to run

```shell
cd /var/www/site
yes | php artisan migrate
yes | php artisan db:seed
```

You are done, and your site should be up.

You can the get to it at https://example.com
