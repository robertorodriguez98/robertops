---
title: "Instalación Gitea"
date: 2023-06-14 08:16:38 +0200
media_subpath: /assets/2023-06-14_gitea
image:
  path: WRaCuwT.png
categories:
    - documentación
tags:
    - git
    - autoalojado
    - docker
    - vps
---

# Gitea

Gitea es una solución ligera de alojamiento de código gestionada por la comunidad y escrita en Go, tiene las principales características que tiene github, incluyendo actions. Ahora veremos la instalación de gitea en la VPS.

## Preparación

En mi caso voy a instalarlo  utilizando `docker-compose`, para ello, y teniendo en cuenta que uso debian, es necesario ejecutar los siguientes comandos:

```shell
apt update
apt install -y docker.io docker-compose
```

## Instalación

Para instalarlo, voy a optar por la opción con una base de datos PostgreSQL. Para ello, en un directorio vacío creamos el siguiente fichero `docker-compose.yml` (cambiando las credenciales, claro):

```yaml
version: "3"

networks:
  gitea:
    external: false

services:
  server:
    image: gitea/gitea:nightly
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=db:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=gitea
    restart: always
    networks:
      - gitea
    volumes:
      - ./gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3200:3000"
      - "222:22"
    depends_on:
      - db

  db:
    image: postgres:14
    restart: always
    environment:
      - POSTGRES_USER=gitea
      - POSTGRES_PASSWORD=gitea
      - POSTGRES_DB=gitea
    networks:
      - gitea
    volumes:
      - ./postgres:/var/lib/postgresql/data
```

y lo desplegamos con

```shell
docker-compose up -d
```

Con eso ya se habrían creado los contenedores. Además, para poder entrar en gitea desde fuera de la VPS usando el dominio, vamos a añadir el siguiente proxy inverso al servidor nginx:

```nginx
server {
    if ($host ~ ^[^.]+\.admichin\.es$) {
        return 301 https://$host$request_uri;
    } # managed by Certbot
        listen 80;
        listen [::]:80;
        server_name gitea.admichin.es;
        return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    ssl    on;
    ssl_certificate /etc/letsencrypt/live/admichin.es-0001/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/admichin.es-0001/privkey.pem; # managed by Certbot

    index index.html index.php index.htm index.nginx-debian.html;
    server_name gitea.admichin.es;

    location / {
            proxy_pass http://localhost:3200;
            include proxy_params;
    }
}
```

Con esto hecho, si accedemos a [gitea.admichin.es](https://gitea.admichin.es) por primera vez, se abrirá la página de configuración:

![configuracion1](es0cMvq.png)

En esta configuración es importante poner el dominio (más abajo, no donde sale en la foto ya que esa es la configuración de la base de datos). Así como establecer la configuración de ssh y el nombre del sitio. Tras finalizar la configuración, o en la misma ya que es una opción, el primer usuario que se cree será el administrador. Con esto ya tendríamos gitea instalado y funcionando.

![principal](dAKzydC.png)

# Actions

Gitea, desde la versión 1.19 permite añadir actions, que son similares a las GitHub actions. Aunque actualicemos a dicha versión, no aparecerán, ya que tenemos que añadir lo siguiente al final del fichero de configuración, que se encuentra en `data/gitea/conf/app.ini`:

```ini
[actions]
ENABLED=true
```

Una vez activado, aparece la siguiente opción en el apartado de administración:

![actions](OeZEsB5.png)

Para el paso que irá a continuación, vamos a necesitar el  token de registro. Para obtenerlo se accede al apartado de Runners y al botón de `Create a new Runner`:

![token](bpHH3qp.png)

## Runners

Un runner es una máquina que ejecuta las tareas de un workflow de actions. En mi caso voy a utilizar un contenedor como runner dentro de la VPS también, pero hay varios métodos:

### En local

Descargamos el binario de [https://gitea.com/gitea/act_runner](https://gitea.com/gitea/act_runner) adecuado para nuestro sistema y ejecutamos los siguientes comandos:

```shell
./act_runner register --no-interactive --instance <instance> --token <token>
```

Donde la instancia es la dirección o IP en la que esté alojada Gitea, y el token es el token que hemos obtenido previamente. Tras esto, ejecutamos el runner:

```shell
./act_runner daemon
```

### En contenedor

Para ejecutarlo con docker voy a usar docker-compose. para ello, creo un nuevo directorio con el siguiente fichero docker-compose.yml:

```yaml
version: "3"

services:
  runner:
    image: gitea/act_runner
    restart: always
    volumes:
      - ./data/act_runner:/data
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - GITEA_INSTANCE_URL=instance
      - GITEA_RUNNER_REGISTRATION_TOKEN=token
```

Al igual que en el caso anterior la instancia es la dirección o IP en la que esté alojada Gitea, y el token es el token que hemos obtenido previamente.

Una vez en ejecución, los runners aparecen de la siguiente manera:

![runners](iN7zF86.png)

## Activar actions

Aunque esté configurado, las actions están desactivadas por defecto en los repositorios. Para activarlas hay que acceder a la configuración, y en el apartado de ajustes avanzados activarlas:

![activar](C9gBaBP.png)

Podemos ver que se ha activado porque aparece el botón de actions en el repositorio, y podemos añadirlas como se añadirían en GitHub:

![boton](DHLtkJY.png)

# Enlaces de interés

- [Gitea Installation with Docker](https://docs.gitea.com/next/installation/install-with-docker)
- [Feature Preview: Gitea Actions](https://blog.gitea.io/2022/12/feature-preview-gitea-actions/)
- [Hacking on Gitea Actions](https://blog.gitea.io/2023/03/hacking-on-gitea-actions/)