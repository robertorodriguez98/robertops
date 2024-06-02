---
title: "Despliegue de aplicaciones de java usando tomcat"
date: 2023-01-24T02:45:29+01:00
draft: false
media_subpath: /assets/2023-01-24-despliegue-java
image:
  path: featured.png
categories:
    - documentación
    - Implantación de Aplicaciones Web
tags:
    - java
    - Apache Tomcat
---

## Tarea 1 Desarrollo y despliegue de una aplicación Java simple

De forma similar a lo que hemos hecho en el Taller 1, desplegamos de forma manual la aplicación Java que encontramos en el repositorio [https://github.com/josedom24/rock-paper-scissors](https://github.com/josedom24/rock-paper-scissors)

Una vez tenemos la carpeta, vamos a compilarla con el siguiente comando:

```bash
mvn package
```

Una vez compilada, vamos a desplegarla en el servidor Tomcat. Para ello, copiamos el fichero war que se ha generado en la carpeta target en la carpeta webapps del servidor Tomcat. Una vez copiado, reiniciamos el servidor Tomcat.

```bash
cp roshambo.war /var/lib/tomcat9/webapps/
systemctl restart tomcat9
```

![rock-paper-scissors](https://i.imgur.com/OpvZ5tu.png)

## Tarea 2 Despliegue de un CMS Java

### Instalación de OpenCMS

Para instalar OpenCMS, vamos a descargar el fichero war de la página de descargas de OpenCMS. Una vez descargado, lo copiamos en la carpeta webapps de Tomcat.

```bash
scp -r opencms.war debian@172.22.200.19:/home/debian/
```

```bash
cp opencms.war /var/lib/tomcat9/webapps/
systemctl restart tomcat9
```

Instalamos la base de datos MariaDB y creamos la base de datos opencms.

```bash
apt install mariadb-server
sudo mysql -u root -p
CREATE DATABASE opencms;
CREATE USER 'java'@'localhost' IDENTIFIED BY 'java';
grant all privileges on opencms. * to 'java'@'localhost' with grant option;
flush privileges;
```

Una vez instalado, accedemos a la aplicación con la url [http://172.22.200.19:8080/opencms/setup](http://172.22.200.19:8080/opencms/setup)

Seguimos los pasos de la instalación, indicando la base de datos que hemos creado y el usuario java/java.

![opencms](https://i.imgur.com/f96vUjU.png)

![opencms2](https://i.imgur.com/xlAvYTT.png)

![opencms3](https://i.imgur.com/e6qvEXP.png)

## Tarea 3 Acceso a las aplicaciones

Instalamos nginx para realizar un proxy inverso para acceder a las aplicaciones.

```bash
apt install nginx
```

Y creamos el siguiente virtualhost en `/etc/nginx/sites-available/opencms.conf`:

```bash
server {
    listen 80;
    listen [::]:80;

    index index.html index.htm index.nginx-debian.html;

    server_name java.roberto.org;

    location / {
        return 301 http://$host/opencms/;
    }

    location /opencms/ {
        proxy_pass http://localhost:8080;
        include proxy_params;
    }

    location /game/ {
        proxy_pass http://localhost:8080/roshambo/;
        include proxy_params;
    }
}
```

Y lo activamos:

```bash
sudo ln -s /etc/nginx/sites-available/opencms.conf /etc/nginx/sites-enabled/
sudo systemctl restart nginx
```

Una vez hecho podemos acceder a las aplicaciones con las siguientes urls:

piedra papel tijera -> [http://java.roberto.org/game/](http://java.roberto.org/game/)

![piedra](https://i.imgur.com/C9svFA4.png)

opencms -> [http://java.roberto.org/](http://java.roberto.org/)

![opencms5](https://i.imgur.com/QAkYCko.png)
