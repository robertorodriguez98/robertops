---
title: "Instalación/migración de aplicaciones web PHP"
date: 2022-12-07T18:15:43+01:00
draft: false
media_subpath: /assets/2022-12-07-migracion-php
image:
  path: featured.png
categories:
    - práctica
    - Implantación de Aplicaciones Web
tags:
    - php
    - Vagrant
    - cms
    - mediawiki
    - Apache
    - nginx
    - vps
---

## Escenario

Vamos a hacer un escenario de vagrant utilizando el siguiente `Vagrantfile`:

```ruby
Vagrant.configure("2") do |config|

config.vm.define :web do |web|
    web.vm.box = "debian/bullseye64"
    web.vm.hostname = "servidor-web-roberto"
    web.vm.synced_folder ".", "/vagrant", disabled: true
    web.vm.network :public_network,
      :dev => "bridge0",
      :mode => "bridge",
      :type => "bridge",
      use_dhcp_assigned_default_route: true
    web.vm.network :private_network,
      :libvirt__network_name => "net1",
      :libvirt__dhcp_enabled => false,
      :ip => "10.0.0.1",
      :libvirt__forward_mode => "veryisolated"
  end
  config.vm.define :bd do |bd|
    bd.vm.box = "debian/bullseye64"
    bd.vm.hostname = "servidor-bd-roberto"
    bd.vm.synced_folder ".", "/vagrant", disabled: true
    bd.vm.network :private_network,
      :libvirt__network_name => "net1",
      :libvirt__dhcp_enabled => false,
      :ip => "10.0.0.2",
      :libvirt__forward_mode => "veryisolated"
  end
end
```

## Configuración de resolución estática

Vamos a configurar la resolución estática de las páginas utilizando la IP pública de la máquina web:

![resolucion](https://i.imgur.com/n78aYSy.png)

## Instalación de un CMS PHP en mi servidor local

En este caso el CMS que vamos a instalar es [Media Wiki](https://www.mediawiki.org/wiki/Manual:Installing_MediaWiki). Ahora vamos a configurar el servidor y la base de datos.

En el servidor web instalamos apache con php:

```bash
apt update
apt install apache2 libapache2-mod-php php php-mysql
```

### Configuración del VirtualHost

Vamos a instalar el cms en `/var/www/mediawiki`, por lo configuramos el vhost en el fichero `etc/apache2/sites-available/mediawiki.conf`:

```apache2
<VirtualHost *:80>
        ServerName www.roberto.org

        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/mediawiki

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet
```

Ahora activamos el VirtualHost

```bash
a2ensite mediawiki
systemctl reload apache2
```

### Configuración de la base de datos

En el servidor que va a tener la base de datos, instalamos mariadb:

```bash
apt update
apt install mariadb-server
mariadb -u root
```

Dentro vamos a crear una base de datos para el CMS y un usuario con permisos:

```sql
GRANT ALL PRIVILEGES ON *.* TO 'remoto'@'%'
IDENTIFIED BY 'remoto' WITH GRANT OPTION;

create database mediawiki;
```

Para configurar el acceso remoto, tenemos que modificar en fichero `/etc/mysql/mariadb.conf.d/50-server.cnf`, la siguiente línea:

```bash
bind-address            = 0.0.0.0
```

Y reiniciamos el servicio.

Ahora desde el cliente creamos el siguiente usuario:

```sql
GRANT ALL PRIVILEGES ON *.* TO 'remoto'@'10.0.0.2' IDENTIFIED BY 'remoto' WITH GRANT OPTION;
```

y podemos conectarnos a la base de datos remota con el siguiente comando:

```bash
mysql -u remoto -h 10.0.0.2 --password=remoto
```

### Instalación MediaWiki

Para instalar media wiki, tenemos que descargar la última versión de la página oficial:

```bash
wget https://releases.wikimedia.org/mediawiki/1.38/mediawiki-1.38.4.tar.gz
tar -xf mediawiki-1.38.4.tar.gz
cp -r mediawiki-1.38.4/* /var/www/mediawiki/
chown -R www-data:www-data /var/www/mediawiki/
```

Antes de iniciar la instalación tenemos que instalar los siguientes paquetes:

```bash
apt install php-mbstring php-xml php-intl -y
systemctl restart apache2.service
```

Ahora seguimos la instalación normalmente, pero en la configuración de la base de datos es importante especificar la IP:

![p2-1](https://i.imgur.com/lUVzDxN.png)

Una vez finalizada la configuración inicial, se descarga el fichero `LocalSettings.php`:

![p2-2](https://i.imgur.com/Ecn7gng.png)

Tenemos que moverlo al Document Root de MediaWiki:

```bash
chown www-data:www-data LocalSettings.php
mv LocalSettings.php /var/www/mediawiki/
```

Una vez realizada la configuración, accediendo a `www.roberto.org` aparece la wiki:

![p2-3](https://i.imgur.com/mT4mBno.png)

#### Instalación de un módulo

Tras configurar el tema, vamos a instalar un módulo: [SimpleCalendar](https://www.mediawiki.org/wiki/Extension:SimpleCalendar):

```bash
wget https://extdist.wmflabs.org/dist/extensions/SimpleCalendar-REL1_38-b7a2f05.tar.gz
tar -xf SimpleCalendar-REL1_38-b7a2f05.tar.gz
mv SimpleCalendar /var/www/mediawiki/extensions/
```

Ahora añadimos la siguiente línea al final de `LocalSettings.php`:

```bash
echo "wfLoadExtension( 'SimpleCalendar' );" >> /var/www/mediawiki/LocalSettings.php
```

Una vez hecho, podemos comprobar que está correctamente instalado accediendo a [http://www.roberto.org/index.php/Especial:Versión](http://www.roberto.org/index.php/Especial:Versi%C3%B3n)

![p2-4](https://i.imgur.com/GYSoi3r.png)

Ya instalado, podemos añadir calendarios a las páginas de la wiki con el siguiente bloque:

```php
{ { #calendar: year=2022 | month=nov | title="calendario" } }
```

Y quedaría de la siguiente forma:

![p2-5](https://i.imgur.com/bNKXNG6.png)

## Instalación del CMS PHP NextCloud

Primero descargamos la última versión y lo movemos al directorio de apache:

```bash
wget https://download.nextcloud.com/server/releases/latest.zip
unzip latest.zip
cp -r nextcloud/ /var/www/
chown -R www-data:www-data /var/www/nextcloud/
```

Ahora configuramos el vhost en el fichero `etc/apache2/sites-available/nextcloud.conf`:

```bash
<VirtualHost *:80>
        ServerName www.cloud.roberto.org        
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/nextcloud        
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined     
</VirtualHost>
```

```bash
a2ensite nextcloud.conf
systemctl reload apache2.service
```

E instalamos los módulos de php necesarios:

```bash
  apt install php-zip php-gd php-curl -y
systemctl reload apache2.service
```

Ahora en la máquina con la base de datos creamos la base de datos para nextcloud:

```bash
create database nextcloud;
```

Tras este paso, podemos acceder a `cloud.roberto.org` para iniciar la instalación, es importante que en la base de datos especifiquemos la ip y el puerto de la máquina con la base de datos:

![p2-6](https://i.imgur.com/dSKyF4C.png)

Una vez finalizada la instalación, ya podremos utilizar nextcloud:

![p2-7](https://i.imgur.com/LKyMGco.png)


---


## DNS del dominio

Para configurar el dns tenemos que mirar la dirección en la configuración del VPS:

![p2-8](https://i.imgur.com/MZtPIqH.png)

y añadir un registro CNAME en la dirección [www.admichin.es](www.admichin.es) que lleve a esa dirección:

![p2-9](https://i.imgur.com/hnTB39X.png)

## Configuración del servidor LEMP

Para instalar el servidor lemp tenemos que instalar los siguientes paquetes:

```bash
apt install 
apt install nginx php php-mysql mariadb-server -y
```

Ahora, en la máquina con la base de datos, creamos un fichero con la copia de seguridad y lo enviamos a la vps:

```bash
mysqldump -u remoto -p -x -A > dbs.sql
scp dbs.sql calcetines@nodriza.admichin.es:/home/calcetines
```

Ahora creamos en la base de datos un usuario con permisos y restauramos las bases de datos:

```sql
GRANT ALL PRIVILEGES ON *.* TO 'admin'@localhost IDENTIFIED BY 'contraseña' WITH GRANT OPTION;
```

```bash
mysql --user admin --password < dbs.sql
```

## Migración de las aplicaciones

Para migrar las aplicaciones, tenemos que moverlas al servidor. En este caso utilizaré rsync ya que permite reanudar la transmisión si se interrumpe, además de ser más rápido que scp:

```bash
rsync -avP /var/www/mediawiki/ calcetines@nodriza.admichin.es:/home/calcetines/mediawiki
rsync -avP /var/www/nextcloud/ calcetines@nodriza.admichin.es:/home/calcetines/nextcloud
```

Una vez finalizado, en este caso vamos a utilizar un solo virtualhost, por lo que los directorios de ambas aplicaciones deben estar en `/var/www/html/nombreaplicacion`:

```bash
upstream php-handler {
    #server 127.0.0.1:9000;
    server unix:/var/run/php/php7.4-fpm.sock;
}

# Set the `immutable` cache control options only for assets with a cache busting `v` argument
map $arg_v $asset_immutable {
    "" "";
    default "immutable";
}

server {
    listen 80;
    listen [::]:80;
    server_name www.admichin.es;

    # Prevent nginx HTTP Server Detection
    #server_tokens off;
    rewrite ^/$ /portal;

    # Path to the root of the domain
    root /var/www/html;

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ^~ /.well-known {
        # The rules in this block are an adaptation of the rules
        # in the cloud `.htaccess` that concern `/.well-known`.

        location = /.well-known/carddav { return 301 /cloud/remote.php/dav/; }
        location = /.well-known/caldav  { return 301 /cloud/remote.php/dav/; }

        location /.well-known/acme-challenge    { try_files $uri $uri/ =404; }
        location /.well-known/pki-validation    { try_files $uri $uri/ =404; }

        # Let cloud's API for `/.well-known` URIs handle all other
        # requests by passing them to the front-end controller.
        return 301 /cloud/index.php$request_uri;
    }
    location ^~ /portal {
        # set max upload size and increase upload timeout:
        client_max_body_size 512M;
        client_body_timeout 300s;
        fastcgi_buffers 64 4K;

        gzip on;
        gzip_vary on;
        gzip_comp_level 4;
        gzip_min_length 256;
        gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
        gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/wasm application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;


        client_body_buffer_size 512k;

        # HTTP response headers borrowed from cloud `.htaccess`
        add_header Referrer-Policy                      "no-referrer"   always;
        add_header X-Content-Type-Options               "nosniff"       always;
        add_header X-Download-Options                   "noopen"        always;
        add_header X-Frame-Options                      "SAMEORIGIN"    always;
        add_header X-Permitted-Cross-Domain-Policies    "none"          always;
        add_header X-Robots-Tag                         "none"          always;
        add_header X-XSS-Protection                     "1; mode=block" always;

        fastcgi_hide_header X-Powered-By;

        index index.php index.html /portal/index.php$request_uri;

        location ~ \.php(?:$|/) {

            fastcgi_split_path_info ^(.+?\.php)(/.*)$;
            set $path_info $fastcgi_path_info;

            try_files $fastcgi_script_name =404;

            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param PATH_INFO $path_info;

            fastcgi_param modHeadersAvailable true;         # Avoid sending the security headers twice
            fastcgi_param front_controller_active true;     # Enable pretty urls
            fastcgi_pass php-handler;

            fastcgi_intercept_errors on;
            fastcgi_request_buffering off;

            fastcgi_max_temp_file_size 0;
        }

        location /portal {
            try_files $uri $uri/ /portal/index.php$request_uri;
        }
    }
    location ~ /\.ht {
          deny all;
         }

    location ^~ /cloud {
        # set max upload size and increase upload timeout:
        client_max_body_size 512M;
        client_body_timeout 300s;
        fastcgi_buffers 64 4K;
        # Enable gzip but do not remove ETag headers
        gzip on;
        gzip_vary on;
        gzip_comp_level 4;
        gzip_min_length 256;
        gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
        gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/wasm application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;
        # HTTP response headers borrowed from cloud `.htaccess`
        add_header Referrer-Policy                      "no-referrer"   always;
        add_header X-Content-Type-Options               "nosniff"       always;
        add_header X-Download-Options                   "noopen"        always;
        add_header X-Frame-Options                      "SAMEORIGIN"    always;
        add_header X-Permitted-Cross-Domain-Policies    "none"          always;
        add_header X-Robots-Tag                         "none"          always;
        add_header X-XSS-Protection                     "1; mode=block" always;

        # Remove X-Powered-By, which is an information leak
        fastcgi_hide_header X-Powered-By;
        index index.php index.html /cloud/index.php$request_uri;

        # Rule borrowed from `.htaccess` to handle Microsoft DAV clients
        location = /cloud {
            if ( $http_user_agent ~ ^DavClnt ) {
                return 302 /cloud/remote.php/webdav/$is_args$args;
            }
        }

        # Rules borrowed from `.htaccess` to hide certain paths from clients
        location ~ ^/cloud/(?:build|tests|config|lib|3rdparty|templates|data)(?:$|/)    { return 404; }
        location ~ ^/cloud/(?:\.|autotest|occ|issue|indie|db_|console)                  { return 404; }
        location ~ \.php(?:$|/) {
            # Required for legacy support
            rewrite ^/cloud/(?!index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|oc[ms]-provider\/.+|.+\/richdocumentscode\/proxy) /cloud/index.php$request_uri;

            fastcgi_split_path_info ^(.+?\.php)(/.*)$;
            set $path_info $fastcgi_path_info;

            try_files $fastcgi_script_name =404;

            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param PATH_INFO $path_info;
           # fastcgi_param HTTPS on;

            fastcgi_param modHeadersAvailable true;         # Avoid sending the security headers twice
            fastcgi_param front_controller_active true;     # Enable pretty urls
            fastcgi_pass php-handler;

            fastcgi_intercept_errors on;
            fastcgi_request_buffering off;

            fastcgi_max_temp_file_size 0;
        }
        location ~ \.(?:css|js|svg|gif|png|jpg|ico|wasm|tflite|map)$ {
            try_files $uri /cloud/index.php$request_uri;
            add_header Cache-Control "public, max-age=15778463, $asset_immutable";
            access_log off;     # Optional: Don't log access to assets

            location ~ \.wasm$ {
                default_type application/wasm;
            }
        }
        location ~ \.woff2?$ {
            try_files $uri /cloud/index.php$request_uri;
            expires 7d;         # Cache-Control policy borrowed from `.htaccess`
            access_log off;     # Optional: Don't log access to assets
        }
        # Rule borrowed from `.htaccess`
        location /cloud/remote {
            return 301 /cloud/remote.php$request_uri;
        }
        location /cloud {
            try_files $uri $uri/ /cloud/index.php$request_uri;
        }
    }
}
```

### MediaWiki

para migrar la aplicación de mediawiki tenemos que realizar los siguientes pasos:

* Primero tenemos que transferir los ficheros que se encuentren en el document root de mediawiki a la vps, en este caso con rsync:

```bash
rsync -avP /var/www/mediawiki/ calcetines@nodriza.admichin.es:/home/calcetines/mediawiki
```

* dentro de la vps lo movemos a su nueva ubicación:

```bash
mv mediawiki /var/www/html/portal
```

* El último paso, es configurar el fichero `LocalSettings.php` (he quitado los comentarios para que sea menos largo):

```php
<?php
if ( !defined( 'MEDIAWIKI' ) ) { exit;
}
$wgSitename = "adMICHIn.es"; $wgMetaNamespace = "AdMICHIn.es";
$wgScriptPath = "/portal";
$wgServer = "http://www.admichin.es";
$wgResourceBasePath = $wgScriptPath;
$wgLogos = [ '1x' => "https://i.imgur.com/KqnlgCE.png",
	
	
	'icon' => "https://i.imgur.com/KqnlgCE.png", ];
$wgEnableEmail = true; $wgEnableUserEmail = true; # UPO $wgEmergencyContact = "apache@������.invalid"; $wgPasswordSender = 
"apache@������.invalid"; $wgEnotifUserTalk = false; # UPO $wgEnotifWatchlist = false; # UPO $wgEmailAuthentication = true;
$wgDBtype = "mysql"; $wgDBserver = "localhost"; $wgDBname = "mediawiki"; $wgDBuser = "admin"; $wgDBpassword = 
"contraseña";
$wgDBprefix = "";
$wgDBTableOptions = "ENGINE=InnoDB, DEFAULT CHARSET=binary";
$wgSharedTables[] = "actor";
$wgMainCacheType = CACHE_NONE; $wgMemCachedServers = [];
$wgEnableUploads = false;
$wgUseInstantCommons = false;
$wgPingback = true;
$wgLanguageCode = "es";
$wgLocaltimezone = "UTC";
$wgSecretKey = "61c7675d604b7bd8b0b434dd7c53d6470ff8797636136e4ef7ade0e08cdaba14";
$wgAuthenticationTokenVersion = "1";
$wgUpgradeKey = "696787eac8f24d0f";
$wgRightsPage = ""; # Set to the title of a wiki page that describes your license/copyright $wgRightsUrl = ""; $wgRightsText = 
""; $wgRightsIcon = "";
$wgDiff3 = "/usr/bin/diff3";
$wgDefaultSkin = "MonoBook";
wfLoadSkin( 'MinervaNeue' ); wfLoadSkin( 'MonoBook' ); wfLoadSkin( 'Timeless' ); wfLoadSkin( 'Vector' );
wfLoadExtension( 'SimpleCalendar' );
$wgUsePathInfo = TRUE;
```

Tras eso mediaWiki estaría totalmente configurado y podremos acceder con: [http://www.admichin.es](http://www.admichin.es)

![m1](https://i.imgur.com/3BgNcj6.png)

### NextCloud

Para migrar nextcloud, el método es diferente. Siguiendo [guía oficial](https://docs.nextcloud.com/server/latest/admin_manual/maintenance/migrating.html) hay que seguir los siguientes pasos:

* En la vps, tenemos que instalar los requisitos previos de nextcloud

```bash
pt install php-zip php-gd php-curl -y
```

* En la máquina original, hay que activar el modo mantenimiento del Nextcloud (desde el document root de nextcloud) y apagar el servidor tras 6-7 minutos:

```bash
sudo -u www-data php occ maintenance:mode --on
systemctl stop apache2
```

![m2](https://i.imgur.com/gFqYaJ9.png)

* Cuando termine copiamos los ficheros de nextcloud a la vps:

```bash
rsync -avP /var/www/nextcloud/ calcetines@nodriza.admichin.es:/home/calcetines/nextcloud
```

* Dentro de la vps lo movemos a su nueva ubicación:

```bash
mv nextcloud /var/www/html/cloud
```

* en el fichero config.php tenemos que adaptar las opciones:

```php
<?php
$CONFIG = array (
  'instanceid' => 'oct5tjcnoj2h',
  'passwordsalt' => 'uz7Kh0ZsihYsbbhIhL/HojMYSVc20y',
  'secret' => 'NxO/97NF1AoG+oCMrY3ryaefvSGO6SHczYjoc5x8NvsLZ1ma',
  'trusted_domains' => 
  array (
    0 => 'www.admichin.es',
  ),
  'datadirectory' => '/var/www/html/cloud/data',
  'dbtype' => 'mysql',
  'version' => '25.0.1.1',
  'overwrite.cli.url' => 'http://www.admichin.es/cloud',
  'dbname' => 'nextcloud',
  'dbhost' => 'localhost',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'oc_roberto',
  'dbpassword' => '}QR947P6^,vV%K$ATu]$W~%)AUhj6X',
  'installed' => true,
  'maintenance' => true,
);
```

* Ahora, teniendo en cuenta que el serverblock de nginx está configurado, comprobamos que al acceder a [http://www.admichin.es/cloud](http://www.admichin.es/cloud) aparece el modo mantenimiento.

* Si aparecece la misma imagen que en el caso anterior, entonces podemos cambiar el valor de configuración de `mainteinance` a false, y recargamos la página:

![m3](https://i.imgur.com/7jYwYOI.png)
![m4](https://i.imgur.com/06VeYQ7.png)