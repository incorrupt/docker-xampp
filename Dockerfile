FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update --fix-missing

# install curl, net-tools, wget, git etc.
RUN apt-get -y install curl net-tools wget apt-transport-https ca-certificates sudo git mc

# Few handy utilities which are nice to have
RUN apt-get -y install nano vim less --no-install-recommends

# update repo for php7
RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
RUN echo "deb https://packages.sury.org/php/ jessie main" > /etc/apt/sources.list.d/php.list
RUN apt-get update

# install xampp
RUN curl -o xampp-linux-installer.run "https://downloadsapachefriends.global.ssl.fastly.net/xampp-files/7.1.8/xampp-linux-x64-7.1.8-0-installer.run?from_af=true"
RUN chmod +x xampp-linux-installer.run
RUN bash -c './xampp-linux-installer.run'
RUN ln -sf /opt/lampp/lampp /usr/bin/lampp

# setup php to path
ENV PATH="/opt/lampp/bin:${PATH}"
RUN echo "PATH=$PATH:/opt/lampp/bin" >> /etc/bash.bashrc

# install composer 
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# enable XAMPP web interface(remove security checks)
RUN sed -i.bak s'/Require local/Require all granted/g' /opt/lampp/etc/extra/httpd-xampp.conf

# enable includes of several configuration files
RUN mkdir /opt/lampp/apache2/conf.d && \
    echo "IncludeOptional /opt/lampp/apache2/conf.d/*.conf" >> /opt/lampp/etc/httpd.conf

# create a /www folder and a symbolic link to it in /opt/lampp/htdocs. It'll be accessible via http://localhost:[port]/www/
RUN mkdir /www
RUN ln -s /www /opt/lampp/htdocs/

# SSH server
RUN apt-get install -y -q supervisor openssh-server
RUN mkdir -p /var/run/sshd

# output supervisor config file to start openssh-server
RUN echo "[program:openssh-server]" >> /etc/supervisor/conf.d/supervisord-openssh-server.conf
RUN echo "command=/usr/sbin/sshd -D" >> /etc/supervisor/conf.d/supervisord-openssh-server.conf
RUN echo "numprocs=1" >> /etc/supervisor/conf.d/supervisord-openssh-server.conf
RUN echo "autostart=true" >> /etc/supervisor/conf.d/supervisord-openssh-server.conf
RUN echo "autorestart=true" >> /etc/supervisor/conf.d/supervisord-openssh-server.conf

# allow root login via password
# root password is: root
RUN sed -ri 's/PermitRootLogin without-password/PermitRootLogin yes/g' /etc/ssh/sshd_config

# set root password
# password hash generated using this command: openssl passwd -1 -salt xampp root
RUN sed -ri 's/root\:\*/root\:\$1\$xampp\$5\/7SXMYAMmS68bAy94B5f\./g' /etc/shadow

RUN apt-get clean
VOLUME [ "/var/log/mysql/", "/var/log/apache2/" ]

EXPOSE 3306
EXPOSE 22
EXPOSE 80

# write a startup script
RUN echo '/opt/lampp/lampp start' >> /startup.sh
RUN echo '/usr/bin/supervisord -n' >> /startup.sh

# add user dev
RUN adduser --disabled-password --gecos '' dev
RUN echo "dev:dev" | chpasswd
RUN usermod -a -G sudo dev

CMD ["sh", "/startup.sh"]
