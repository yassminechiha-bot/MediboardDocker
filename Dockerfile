FROM ubuntu:14.04

# Install apache, PHP and subversion
RUN apt-get update
RUN apt-get install -y software-properties-common
RUN apt-get install -y python-software-properties
RUN add-apt-repository ppa:ondrej/php
RUN apt-get update && apt-get -y --force-yes upgrade && DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install apache2 php5.6 php5.6-mysql php5.6-dev php5.6-gd libapache2-mod-php5.6 php5.6-mbstring php5.6-zip libgpgme11-dev php-pear libzip-dev libgd-dev php5.6-curl php5.6-soap php5.6-apc php5.6-bcmath php5.6-odbc libmdbodbc1
RUN apt-get -y --force-yes install subversion libapache2-mod-svn

# Enable apache mods
RUN a2enmod php5.6
RUN a2enmod rewrite

# Update the PHP.ini file, enable <? ?> tags and quieten logging.
RUN sed -i "s/short_open_tag = Off/short_open_tag = On/" /etc/php/5.6/apache2/php.ini
RUN sed -i "s/error_reporting = .*$/error_reporting = E_ERROR | E_WARNING | E_PARSE/" /etc/php/5.6/apache2/php.ini
RUN sed -i "s/memory_limit = 128M/memory_limit = 256M/" /etc/php/5.6/apache2/php.ini

# Manually set up the apache environment variables
ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
ENV APACHE_LOG_DIR /var/log/apache2
ENV APACHE_LOCK_DIR /var/lock/apache2
ENV APACHE_PID_FILE /var/run/apache2.pid

# Expose apache
EXPOSE 80

# Download mediboard src
WORKDIR /var/www/
RUN svn co svn://svn.code.sf.net/p/mediboard/code/trunk/ mediboard

# Change mediboard files access rights
ADD utils/access-rights.sh .
RUN /bin/sh access-rights.sh -g www-data

# Install dependencies
RUN pear install config
RUN pear install php_codesniffer
RUN pecl install zip
RUN pecl install gnupg
RUN sed -i "s?;   extension=msql.so?;   extension=msql.so\nextension=gnupg.so?" /etc/php/5.6/cli/php.ini
RUN sed -i "s?;   extension=msql.so?;   extension=msql.so\nextension=gnupg.so?" /etc/php/5.6/apache2/php.ini
RUN apt-get -y --force-yes install php5.6-xml 

# Update the default apache site with the config
ADD utils/apache-config.conf /etc/apache2/sites-enabled/000-default.conf
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# By default start up apache in the foreground, override with /bin/bash for interative
CMD /usr/sbin/apache2ctl -D FOREGROUND