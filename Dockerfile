FROM ubuntu:xenial-20190222 AS add-apt-repositories

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y wget \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv E1DD270288B4E6030699E45FA1715D88E1DF1F24 \
 && echo "deb http://ppa.launchpad.net/git-core/ppa/ubuntu xenial main" >> /etc/apt/sources.list \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv 80F70E11F0F0D5F10CB20E62F5DA5F09C3173AA6 \
 && echo "deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu xenial main" >> /etc/apt/sources.list \
 && apt-key adv --keyserver keyserver.ubuntu.com --recv 8B3981E7A6852F782CC4951600A6F0A3C300EE8C \
 && echo "deb http://ppa.launchpad.net/nginx/stable/ubuntu xenial main" >> /etc/apt/sources.list \
 && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
 && echo 'deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main' > /etc/apt/sources.list.d/pgdg.list

FROM ubuntu:xenial-20190222

LABEL maintainer="sameer@damagehead.com"

ENV RUBY_VERSION=2.4 \
    REDMINE_VERSION=4.1.1 \
    REDMINE_USER="redmine" \
    REDMINE_HOME="/home/redmine" \
    REDMINE_LOG_DIR="/var/log/redmine" \
    REDMINE_ASSETS_DIR="/etc/docker-redmine" \
    RAILS_ENV=production

ENV REDMINE_INSTALL_DIR="${REDMINE_HOME}/redmine" \
    REDMINE_DATA_DIR="${REDMINE_HOME}/data" \
    REDMINE_BUILD_ASSETS_DIR="${REDMINE_ASSETS_DIR}/build" \
    REDMINE_RUNTIME_ASSETS_DIR="${REDMINE_ASSETS_DIR}/runtime"

COPY --from=add-apt-repositories /etc/apt/trusted.gpg /etc/apt/trusted.gpg

COPY --from=add-apt-repositories /etc/apt/sources.list /etc/apt/sources.list
COPY --from=add-apt-repositories /etc/apt/sources.list.d/pgdg.list /etc/apt/sources.list.d/

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      supervisor logrotate nginx mysql-client postgresql-client ca-certificates sudo tzdata libssl-dev\
      imagemagick subversion git cvs bzr mercurial darcs rsync ruby${RUBY_VERSION} locales openssh-client \
      gcc g++ make patch pkg-config gettext-base ruby${RUBY_VERSION}-dev libc6-dev zlib1g-dev libxml2-dev \
      libmysqlclient20 libpq5 libyaml-0-2 libcurl3 libssl1.0.0 uuid-dev xz-utils \
      libxslt1.1 libffi6 zlib1g gsfonts vim-tiny ghostscript \
      libcurl4-openssl-dev libgnutls28-dev libghc-hsopenssl-dev libghc-hsopenssl-dev\
      openssh-server openssl libssl-dev build-essential libssh2-1 libssh2-1-dev cmake libgpg-error-dev libmysqlclient-dev \
 && update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX \
 && gem install --no-document bundler \
 && rm -rf /var/lib/apt/lists/*

#RUN apt-get update \
# && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
#      openssh-server openssl libssl-dev build-essential libssh2-1 libssh2-1-dev cmake libgpg-error-dev libmysqlclient-dev \
# && update-locale LANG=C.UTF-8 LC_MESSAGES=POSIX \
# && apt-get clean\
# && rm -rf /var/lib/apt/lists/*

# Install gitilite as user git
RUN id
RUN useradd -m git

# -  login to "git" on the server
# -  make sure your ssh public key from your workstation has been copied as $HOME/YourName.pub
WORKDIR /home/git
RUN sudo -HEu git git clone git://github.com/sitaramc/gitolite /home/git/gitolite
RUN sudo -HEu git mkdir -p /home/git/bin
RUN sudo -HEu git gitolite/install -to /home/git/bin

COPY forgitolite/redmine_sudoers /etc/sudoers.d/redmine
RUN chmod 440 /etc/sudoers.d/redmine

##### Install gems 

#RUN gem install rugged --version '= 0.99.0'
#RUN gem install coderay --version '= 1.1.2'

##########################################

COPY assets/build/ ${REDMINE_BUILD_ASSETS_DIR}/

RUN bash ${REDMINE_BUILD_ASSETS_DIR}/install.sh

COPY assets/runtime/ ${REDMINE_RUNTIME_ASSETS_DIR}/

COPY assets/tools/ /usr/bin/

COPY entrypoint.custom.sh /sbin/entrypoint.custom.sh
RUN chmod 755 /sbin/entrypoint.custom.sh
 
COPY entrypoint.sh /sbin/entrypoint.sh

WORKDIR ${REDMINE_INSTALL_DIR}

RUN sudo -HEu redmine gem install coderay --user-install
#RUN sudo -HEu redmine gem install rugged --version '= 0.99.0' --user-install
RUN sudo -HEu redmine bundle install --path vendor/bundle
RUN sudo -HEu redmine bundle add coderay


WORKDIR ${REDMINE_INSTALL_DIR}/plugins/redmine_git_hosting/ssh_keys/

RUN chmod -R 755 ${REDMINE_INSTALL_DIR}/plugins/redmine_git_hosting/ssh_keys/
RUN sudo -HEu redmine sh -c "cd /tmp;ssh-keygen -N '' -f redmine_gitolite_admin_id_rsa"

RUN cp -p /tmp/redmine_gitolite_admin_id_rsa* ${REDMINE_INSTALL_DIR}/plugins/redmine_git_hosting/ssh_keys/
RUN cp -p /tmp/redmine_gitolite_admin_id_rsa.pub ${REDMINE_INSTALL_DIR}/plugins/redmine_git_hosting/ssh_keys/

RUN sudo -HEu git /home/git/bin/gitolite setup -pk /tmp/redmine_gitolite_admin_id_rsa.pub

RUN sudo -HEu git sed -i \
  "s:GIT_CONFIG_KEYS.*:GIT_CONFIG_KEYS  =>  '.*',:" \
  /home/git/.gitolite.rc

RUN sudo -HEu git sed -i \
  "s:UMASK.*:UMASK                    =>  0027,:" \
  /home/git/.gitolite.rc

RUN sudo -HEu git sed -i   "0,/\# LOCAL_CODE/s:\# LOCAL_CODE.*:LOCAL_CODE       =>  \"\$ENV{HOME}/local\"\,:"   /home/git/.gitolite.rc

RUN usermod -a -G git redmine
RUN chmod -R g+rX /home/git/repositories

RUN chmod 755 /sbin/entrypoint.sh \
 && sed -i '/session    required     pam_loginuid.so/c\#session    required   pam_loginuid.so' /etc/pam.d/cron

EXPOSE 80/tcp 443/tcp 22/tcp

WORKDIR ${REDMINE_INSTALL_DIR}

ENTRYPOINT ["/sbin/entrypoint.sh"]

CMD ["app:start"]
