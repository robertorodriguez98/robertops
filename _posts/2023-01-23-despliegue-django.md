---
title: "Despliegue de aplicaciones python sobre django"
date: 2023-01-23T08:47:22+01:00
draft: false
media_subpath: /assets/2023-01-23-despliegue-django
image:
  path: featured.png
categories:
    - documentación
    - Implantación de Aplicaciones Web
tags:
    - Python
    - django
---


## Tarea 1 Entorno de desarrollo

He elegido como entorno de desarrollo la máquina bravo.

Primero creamos un entorno virtual de python3 e instalamos las dependencias necesarias para que funcione el proyecto.

```bash
python3 -m venv django 
source django/bin/activate
pip install django
```

Ahora descargamos el proyecto de github:

```bash
git clone https://github.com/robertorodriguez98/django_tutorial
```

### Configuración de django

Comprobamos que vamos a trabajar con una base de datos sqlite. Para ello tenemos que consultar el fichero settings.py. En este caso la base de datos se llama db.sqlite3.

```bash
(django)$ cd django_tutorial
(django)$ cat django_tutorial/settings.py | egrep -A 5 'DATABASES';
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}
```

Para poder acceder desde la dirección www.roberto.gonzalonazareno.org, tenemos que modificar el fichero `django_tutorial/settings.py` y añadir la dirección a la lista de hosts permitidos de la siguiente manera:.

```python
ALLOWED_HOSTS = ['www.roberto.gonzalonazareno.org']
```

Ahora creamos la base de datos:

```bash
(django)$ python manage.py migrate
```

Y el usuario administrador:

```bash
(django)$ python3 manage.py createsuperuser
```

Ahora ejecutamos el servidor web de desarrollo:

```bash
(django)$ python3 manage.py runserver 0.0.0.0:8000
```

Y accedemos a la zona de administración, en este caso en la dirección [www.roberto.gonzalonazareno.org:8000/admin](www.roberto.gonzalonazareno.org:8000/admin) y añadimos dos preguntas con sus posibles respuestas.

![Zona de administración](https://i.imgur.com/DZW2zzb.png)

* Comprueba en el navegador que la aplicación está funcionando, accede a la url /polls.

![Página principal](https://i.imgur.com/p4ZeXNj.png)

![Página de votación1](https://i.imgur.com/Bq4Tpml.png)

![Página de votación2](https://i.imgur.com/DWNxLFr.png)


### Configuración del servidor web

En bravo, el servidor web apache2 ya está instalado y configurado para servir páginas web estáticas. Para servir páginas web dinámicas, tenemos que instalar el módulo wsgi.

```bash
sudo dnf install python3-mod_wsgi
```

Ahora, para que el entorno sea similar al de producción, movemos el proyecto y el entorno virtual a la ruta `/var/www/html/django_tutorial` y `/var/www/html/django` respectivamente.

```bash
sudo mv django_tutorial /var/www/html/
sudo mv django /var/www/html/
```

Creamos el contenido estático de la aplicación:

```bash
sudo python3 manage.py collectstatic
```

Editamos el fichero `/var/www/html/django_tutorial/django_tutorial/settings.py` y modificamos las siguientes líneas:

```python
ALLOWED_HOSTS = ['*']
STATIC_ROOT = '/var/www/html/django_tutorial/static/'
```

Ahora configuraremos el servidor apache para que sirva la aplicación django. Para ello, tenemos que crear un fichero de configuración en la ruta `/etc/httpd/sites-available/django.conf` con el siguiente contenido:

```apache
<VirtualHost python.roberto.gonzalonazareno.org:80>
    ServerName python.roberto.gonzalonazareno.org
    DocumentRoot /var/www/html/django_tutorial

    Alias /static/ /var/www/html/django_tutorial/static/

    WSGIDaemonProcess django_tutorial python-path=/var/www/html/django_tutorial:/var/www/html/django/lib/python3.9/site-packages
    WSGIProcessGroup django_tutorial
    WSGIScriptAlias / /var/www/html/django_tutorial/django_tutorial/wsgi.py

    ErrorLog /var/log/httpd/django_tutorial_error.log
    CustomLog /var/log/httpd/django_tutorial_access.log combined
</VirtualHost>
```

Para que funcione la configuración tenemos que activar el sitio web y reiniciar el servidor web:

```bash
sudo ln -s /etc/httpd/sites-available/django.conf /etc/httpd/sites-enabled/django.conf
sudo systemctl restart httpd
```

Ahora podemos acceder a la aplicación desde la dirección [python.roberto.gonzalonazareno.org](http://python.roberto.gonzalonazareno.org).

## Tarea 2: Entorno de producción

Vamos a realizar el despliegue de nuestra aplicación en un entorno de producción, para ello vamos a utilizar nuestro VPS, sigue los siguientes pasos:

### Instalación de django y base de datos

Clonamos el repositorio:

```bash
git clone https://github.com/robertorodriguez98/django_tutorial
```

Creamos el entorno virtual:

```bash
python3 -m venv django 
source django/bin/activate
cd django_tutorial
pip install -r requirements.txt
```

Instalamos el módulo que permite que python trabaje con mysql:

```bash
sudo apt install libmariadb-dev
pip install mysqlclient
```

Tras crear un usuario y la base de datos,  configuramos la aplicación para trabajar con mysql, para ello modifica la configuración de la base de datos en el archivo `settings.py`:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'django',
        'USER': 'djadmin',
        'PASSWORD': 'djadmin',
        'HOST': 'localhost',
        'PORT': '',
    }
}
```

Creamos la copia de seguridad de la aplicación en bravo:

```bash
sudo python manage.py dumpdata > /home/roberto/basedatos.json
```

y la restauramos en el VPS:

```bash
(django)$ python manage.py migrate
(django)$ python manage.py loaddata basedatos.json
Installed 57 object(s) from 1 fixture(s)
```

Finalmente generamos el contenido estático:

```bash
(django)$ python manage.py collectstatic
```

### Configuración de nginx

Instalamos uwsgi:

```bash
pip install uwsgi
```

Podemos comprobar que funciona correctamente:

```bash
uwsgi --http :8080 --chdir /home/calcetines/django_tutorial --wsgi-file django_tutorial/wsgi.py --process 4 --threads 2 --master 
```

Creamos el fichero de configuración de uwsgi en `/home/calcetines/django/servidor.ini`:

```bash
[uwsgi]
http = :8080
chdir = /home/calcetines/django_tutorial 
wsgi-file = django_tutorial/wsgi.py
processes = 4
threads = 2
```

Ahora crearemos la unidad de systemd para que se ejecute uwsgi como servicio en el fichero `/etc/systemd/system/uwsgi-django.service`:

```bash
[Unit]
Description=uwsgi-django
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
User=www-data
Group=www-data
Restart=always

ExecStart=/home/calcetines/django/bin/uwsgi /home/calcetines/django/servidor.ini
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID

WorkingDirectory=/home/calcetines/django_tutorial
Environment=PYTHONPATH='/home/calcetines/django_tutorial:/home/calcetines/django/lib/python3.9/site-packages'

PrivateTmp=true
```

activamos el servicio:

```bash
systemctl enable uwsgi-django.service
systemctl start uwsgi-django.service
```

Ahora configuramos nginx como proxy inverso añadiendo la siguiente configuración en el fichero `/etc/nginx/sites-available/django`:

```bash
server {
    listen          80;
    server_name     python.admichin.es;
    
    if ($host ~ ^[^.]+\.admichin\.es$) {
        return 301 https://$host$request_uri;
    } # managed by Certbot

}

server {
    listen          443 ssl;
    server_name     python.admichin.es;
    access_log      /var/log/nginx/example.com_access.log combined;
    error_log       /var/log/nginx/example.com_error.log error;

        ssl_certificate /etc/letsencrypt/live/admichin.es-0001/fullchain.pem; # managed by Certbot
        ssl_certificate_key /etc/letsencrypt/live/admichin.es-0001/privkey.pem; # managed by Certbot

    location /static/ {
        root /home/calcetines/django_tutorial;
    }

    location / {
        proxy_pass         http://localhost:8080/;
        include proxy_params;
        proxy_redirect     off;

        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    }
}
```

Desactivamos el modo debug en el fichero `settings.py`:

```python
DEBUG = False
```

Finalmente accedemos a la página web en [python.admichin.es](https://python.admichin.es) y comprobamos que funciona correctamente.

![base](https://i.imgur.com/ULmiDVn.png)

![admin](https://i.imgur.com/c77oBhu.png)

![polls](https://i.imgur.com/TnfrXlx.png)

## Tarea 3: Modificación de nuestra aplicación

### En el entorno de desarrollo

Vamos a hacer las siguientes modificaciones:

* Modificamos el fichero `django_tutorial/polls/templates/polls/index.html` para que aparezca nuestro nombre.
* Modificamos la imagen de fondo que se ve la aplicación. Para hacerlo debemos modificar el fichero `django_tutorial/polls/static/polls/css/style.css` y cambiar la siguiente línea, estando la imagen en la carpeta `django_tutorial/polls/static/polls/images`:

```css
    background: white url("images/gundam.jpg");
```

Ahora vamos a crear una nueva tabla en la base de datos para almacenar las categorías de las preguntas. Para ello sigue los siguientes pasos:

* Se Añade un nuevo modelo al fichero `django_tutorial/polls/models.py`:

```python
class Categoria(models.Model):	
    Abr = models.CharField(max_length=4)
    Nombre = models.CharField(max_length=50)

    def __str__(self):
        return self.Abr+" - "+self.Nombre
```

* Se crea una nueva migración.

```bash
(django)$ sudo python manage.py makemigrations --name tabla_categoria

Migrations for 'polls':
  polls/migrations/0002_tabla_categoria.py
    - Create model Categoria
```

* Se realiza la migración.

```bash
(django)$ sudo python manage.py migrate
Operations to perform:
  Apply all migrations: admin, auth, contenttypes, polls, sessions
Running migrations:
  Applying polls.0002_tabla_categoria... OK
```

* Se añade el nuevo modelo al sitio de administración de django modificando el fichero `django_tutorial/polls/admin.py`:

```python
from .models import Choice, Question, Categoria

[...]

admin.site.register(Categoria)  
```

Para que los cambios se trasladen al entorno de producción debemos realizar los siguientes pasos:

```bash
(django)$ sudo python manage.py
(django)$ sudo python manage.py dumpdata > basedatos2.json
(django)$ sudo python manage.py collectstatic # este no hace falta para el entorno de producción
(django)$ git push
```

### En el entorno de producción

* Se realiza la migración.

```bash
(django)$ git pull
(django)$ sudo python manage.py migrate
(django)$ sudo python manage.py loaddata basedatos2.json
(django)$ sudo python manage.py collectstatic
```

Podemos comprobar que se han producido los cambios:

![base](https://i.imgur.com/nSoCgbk.png)

![admin](https://i.imgur.com/s5iUxOB.png)

![polls](https://i.imgur.com/UrEhNQj.png)