
# Introduction

Dockerfile to build a [Redmine](http://www.redmine.org/) container image.
Based on Current Version: **sameersbn/redmine:4.1.1-2**

Used plugins:  
  
  *[Additionals](https://github.com/alphanodes/additionals.git)  
*[Redmine_bootstrap_kit](https://github.com/jbox-web/redmine_bootstrap_kit.git)  
*[Redmine_git_hosting](https://github.com/jbox-web/redmine_git_hosting.git)



Gitolite:  
*[Gitolite](http://github.com/sitaramc/gitolite) version 3.6.11

Prerequisite:
```bash
sudo mkdir -p /srv/docker/redmine/redmine/plugins
cd /srv/docker/redmine/redmine/plugins
sudo git clone git://github.com/alphanodes/additionals.git
sudo git clone https://github.com/jbox-web/redmine_bootstrap_kit.git
sudo git clone https://github.com/jbox-web/redmine_git_hosting.git
```

```bash
sudo cp Gemfile_git_hosting /srv/docker/redmine/redmine/plugins/redmine_git_hosting/Gemfile
```

```bash
sudo mkdir -p /srv/docker/redmine/redmine/certs

sudo openssl genrsa -out redmine.key 2048
sudo openssl req -new -key redmine.key -out redmine.csr
sudo openssl x509 -req -days 365 -in redmine.csr -signkey redmine.key -out redmine.crt
sudo openssl dhparam -out dhparam.pem 2048
sudo chmod 400 /srv/docker/redmine/redmine/certs/redmine.key
```
```bash
sudo cp pre-install.sh /srv/docker/redmine/redmine/plugins
```

Run:

```bash
docker-compose up
```

Post install:

1. Enable Xitolite repositories in Administration -> Settings -> Repositories

2. Configure plugin settings in Administration -> Redmine Git Hosting (don't forget to click on "Instal hooks!" on "Hooks" tab)

3. Check your installation in Administration -> Redmine Git Hosting Config Checks tab.

# References
    * http://www.redmine.org/
    * http://www.redmine.org/projects/redmine/wiki/Guide
    * http://www.redmine.org/projects/redmine/wiki/RedmineInstall  
    * http://redmine-git-hosting.io/get_started/
    * https://github.com/baracoder/docker-redmine-git-hosting
