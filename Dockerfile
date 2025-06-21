FROM php:5.6-apache

# Remplace les sources Debian par celles des archives
RUN sed -i 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' /etc/apt/sources.list \
    && sed -i 's|http://security.debian.org/debian-security|http://archive.debian.org/debian-security|g' /etc/apt/sources.list \
    && apt-get update || true \
    && apt-get install -y --allow-unauthenticated --no-install-recommends \
        subversion \
        libgpgme11-dev \
        libzip-dev \
        libgd-dev \
        unzip \
    && rm -rf /var/lib/apt/lists/*


# Installe les extensions PHP
RUN docker-php-ext-install mysql mysqli gd zip pdo pdo_mysql \
    && pecl install gnupg \
    && docker-php-ext-enable gnupg \
    && docker-php-ext-enable pdo_mysql



# Active le module Apache rewrite
RUN a2enmod rewrite

# Configuration PHP
RUN echo "short_open_tag = On" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "error_reporting = E_ERROR | E_WARNING | E_PARSE" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "memory_limit = 256M" >> /usr/local/etc/php/conf.d/custom.ini

# Installer PEAR packages
RUN pear install config \
    && pear install PHP_CodeSniffer

# Télécharger Mediboard
WORKDIR /var/www/html
RUN svn co svn://svn.code.sf.net/p/mediboard/code/trunk/ mediboard

# Ajout des droits
ADD utils/access-rights.sh /var/www/html/
RUN chmod +x /var/www/html/access-rights.sh && /bin/sh /var/www/html/access-rights.sh -g www-data

# Config Apache
ADD utils/apache-config.conf /etc/apache2/sites-enabled/000-default.conf
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

EXPOSE 80
CMD ["apache2-foreground"]
