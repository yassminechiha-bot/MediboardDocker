FROM php:5.6-apache

# ✅ Fix pour les dépôts expirés de Debian Stretch
RUN echo "deb http://archive.debian.org/debian stretch main contrib non-free" > /etc/apt/sources.list \
    && echo "Acquire::Check-Valid-Until \"false\";" > /etc/apt/apt.conf.d/99no-check-valid-until \
    && apt-get update || true

# ✅ Installer les paquets système nécessaires
RUN apt-get install -y --allow-unauthenticated --no-install-recommends \
        subversion \
        libgpgme11-dev \
        libzip-dev \
        libgd-dev \
        unzip \
        libxml2-dev \
        unixodbc-dev \
        libbz2-dev \
        libmcrypt-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libpq-dev \
        wget \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

# ✅ Installer manuellement php-pear (car indisponible via apt)
RUN wget http://pear.php.net/go-pear.phar \
    && php go-pear.phar -d preferred_state=stable

# ✅ Configuration et installation des extensions PHP (sans pdo_odbc d'abord)
RUN docker-php-ext-install \
        mysql \
        mysqli \
        gd \
        zip \
        pdo \
        pdo_mysql \
        bcmath \
        soap

# ✅ Configuration spécifique pour pdo_odbc avec vérification
RUN if [ -f /usr/include/sql.h ] || [ -f /usr/local/include/sql.h ]; then \
        echo "ODBC headers found, installing pdo_odbc..."; \
        docker-php-ext-configure pdo_odbc --with-pdo-odbc=unixODBC,/usr && \
        docker-php-ext-install pdo_odbc; \
    else \
        echo "ODBC headers not found, skipping pdo_odbc installation..."; \
        echo "Available header files:"; \
        find /usr -name "*.h" | grep -i odbc || echo "No ODBC headers found"; \
    fi

# ✅ Installer les extensions PECL
RUN pecl install gnupg \
    && pecl install apcu-4.0.11 \
    && docker-php-ext-enable gnupg apcu pdo_mysql

# ✅ Activer le module Apache rewrite
RUN a2enmod rewrite

# ✅ Configuration PHP personnalisée
RUN echo "short_open_tag = On" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "error_reporting = E_ERROR | E_WARNING | E_PARSE" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "memory_limit = 256M" >> /usr/local/etc/php/conf.d/custom.ini

# ✅ Installer PHP_CodeSniffer via PEAR
RUN pear install config \
    && pear install PHP_CodeSniffer

# ✅ Télécharger Mediboard via SVN
WORKDIR /var/www/html
RUN svn co svn://svn.code.sf.net/p/mediboard/code/trunk/ mediboard

# ✅ Ajout des droits
ADD utils/access-rights.sh /var/www/html/
RUN chmod +x /var/www/html/access-rights.sh && /bin/sh /var/www/html/access-rights.sh -g www-data

# ✅ Config Apache
ADD utils/apache-config.conf /etc/apache2/sites-enabled/000-default.conf
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

# ✅ Script de mise à jour DB
ADD utils/update-schema.sh /var/www/html/update-schema.sh
RUN chmod +x /var/www/html/update-schema.sh

EXPOSE 80
CMD ["apache2-foreground"]