---
layout: post
title: "Sistema de copias de seguridad"
date: 2023-03-07T02:15:04+01:00
media_subpath: /assets/2023-03-07-copias-seguridad
image:
  path: Se2J1kp.png
categories:
    - documentación
    - Administración de Sistemas Operativos
tags:
    - bacula
    - copia de seguridad
    - OpenStack
---

## Enunciado

Implementar un sistema de copias de seguridad para las instancias del cloud, teniendo en cuenta las siguientes características:

* Selecciona una aplicación para realizar el proceso: bacula, amanda, shell script con tar, rsync, dar, afio, etc.
* Utiliza una de las instancias como servidor de copias de seguridad, añadiéndole un volumen y almacenando localmente las copias de seguridad que consideres adecuadas en él.
* El proceso debe realizarse de forma completamente automática
* Selecciona qué información es necesaria guardar (listado de paquetes, ficheros de configuración, documentos, datos, etc.)
* Realiza semanalmente una copia completa
* Realiza diariamente una copia incremental o diferencial (decidir cual es más adecuada)
* Implementa una planificación del almacenamiento de copias de seguridad para una ejecución prevista de varios años, detallando qué copias completas se almacenarán de forma permanente y cuales se irán borrando
* Selecciona un directorio de datos "críticos" que deberá almacenarse cifrado en la copia de seguridad, bien encargándote de hacer la copia manualmente o incluyendo la contraseña de cifrado en el sistema
* Incluye en la copia los datos de las nuevas aplicaciones que se vayan instalando durante el resto del curso
* Utiliza una ubicación secundaria para almacenar las copias de seguridad. Solicita acceso o la instalación de las aplicaciones que sean precisas.

La corrección consistirá tanto en la restauración puntual de un fichero en cualquier fecha como la restauración completa de una de las instancias la última semana de curso.

---

El escenario es el siguiente:

![escenario](os.drawio.png)

| Máquina | IPs | tipo |
| :-: | :-: | :-: |
| alfa | 172.22.200.218, 172.16.0.1, 192.168.0.1 | Debian |
| bravo | 172.16.0.200 | Rocky Linux |
| charlie | 192.168.0.2 | Contenedor ubuntu |
| delta | 192.168.0.3 | Contenedor ubuntu |

### Preparaciones previas

He decidido hacer las copias de seguridad desde alfa, ya que tiene conexión directa con las otras instancias. Para ello, voy a utilizar **bacula**, junto con su interfaz web **baculum**, tras ver las características de las distintas herramientas.

Antes de la instalación, compruebo que en alfa en total se han usado en disco 4.5 GB y en bravo 1.9 GB. Como charlie y delta son contenedores, el espacio ya se ha contado en alfa. Teniendo en cuenta el espacio usado, con un disco de 30 GB debería ser suficiente para guardar las copias de seguridad, tanto incrementales como completas.

Al disco le he instalado XFS por sus características de tolerancia a fallos, y lo he añadido a `/etc/fstab` para que se monte automáticamente al iniciar el sistema.

Creo la carpeta `/bacula` en la que va a estar montado permanentemente el disco, y le cambio el propietario y los permisos:

```bash
mkdir -p /bacula
chown -R bacula:bacula /bacula/
chmod 755 -R /bacula
```

Ahora, añado la siguiente línea al fichero `/etc/fstab`:

```bash
UUID=5f086e6b-6937-460b-93ab-1a65a9e12544 /bacula xfs defaults 0 1
```

## Instalación de bacula

Primero instalo los paquetes de bacula

```bash
apt install bacula bacula-common-mysql bacula-director-mysql
```

Durante la instalacion de `bacula-director-mysql` pregunta lo siguiente, le doy a yes e introduzco la contraseña de la base de datos.

![bacula-director-mysql](R9BRtUi.png)

Ahora instalo baculum, primero añado los repositorios:

```bash
wget -qO - http://www.bacula.org/downloads/baculum/baculum.pub | apt-key add -
echo "deb http://www.bacula.org/downloads/baculum/stable/debian buster main
deb-src http://www.bacula.org/downloads/baculum/stable/debian buster main" > /etc/apt/sources.list.d/baculum.list
```

Primero instalo los paquetes de la api

```bash
apt update
apt-get install apache2 baculum-common baculum-api baculum-api-apache2
a2enmod rewrite
a2ensite baculum-api
systemctl restart apache2

```

Y ahora los paquetes de la interfaz web

```bash
apt-get install baculum-common baculum-web baculum-web-apache2
a2enmod rewrite
a2ensite baculum-web
systemctl restart apache2
```

#### Configuración de la api

Primero accedo a http://172.22.200.218:9096/ , introduzco el usuario y contraseña por defecto (admin/admin) y configuro la api:

![configuracion api](PnRV17i.png)

Ahora, para permitir el acceso a la consola de bacula, edito el fichero `nano /etc/sudoers.d/baculum-api` y añado las  siguiente líneas:

```bash
Defaults:www-data !requiretty
www-data ALL = (root) NOPASSWD: /usr/sbin/bconsole
www-data ALL = (root) NOPASSWD: /usr/sbin/bdirjson
www-data ALL = (root) NOPASSWD: /usr/sbin/bsdjson
www-data ALL = (root) NOPASSWD: /usr/sbin/bfdjson
www-data ALL = (root) NOPASSWD: /usr/sbin/bbconsjson
www-data ALL = (root) NOPASSWD: /usr/bin/systemctl start bacula-dir
www-data ALL = (root) NOPASSWD: /usr/bin/systemctl stop bacula-dir
www-data ALL = (root) NOPASSWD: /usr/bin/systemctl restart bacula-dir
www-data ALL = (root) NOPASSWD: /usr/bin/systemctl start bacula-sd
www-data ALL = (root) NOPASSWD: /usr/bin/systemctl stop bacula-sd
www-data ALL = (root) NOPASSWD: /usr/bin/systemctl restart bacula-sd
www-data ALL = (root) NOPASSWD: /usr/bin/systemctl start bacula-fd
www-data ALL = (root) NOPASSWD: /usr/bin/systemctl stop bacula-fd
www-data ALL = (root) NOPASSWD: /usr/bin/systemctl restart bacula-fd
```

![sudoers](H6QUnsE.png)

![confuracionapi2](5bNs8rG.png)

![confuracionapi3](OygLekr.png)

![confuracionapi4](57Vn21e.png)

Ahora creamos un usuario y una contraseña para la api

![confuracionapi5](dKYQjql.png)

Configuramos, ahora si, baculum en http://172.22.200.218:9095/

![confbaculum](mcdrvnm.png)

y utilizamos las credenciales de la api en la configuración:

![confbaculum2](YnQYUAz.png)

![confbaculum3](fbTDdCT.png)

## Configuración del servidor en alfa

### Selecciona qué información es necesaria guardar

En todas las instancias voy a guardar el contenido de /home, /etc, /var, /opt, /usr/share (menos los archivos temporales de var). Además de esto, en diferentes instancias voy a guardar lo siguiente:

| Instancia | Servicios | Localización |
| --- | --- | --- |
| alfa | bacula | /var/log |
| bravo | httpd | /var/www, /etc/httpd |
| charlie | dns | /var/chache/bind, /etc/bind |
| delta | correo | /etc/postfix |

Cada día voy a hacer copias incrementales, cada semana se realizará una completa, al igual que cada mes.

Teniendo en cuenta esto, voy a configurar alfa utilizando los ficheros de configuración (por facilidad respecto a la interfaz web). Primero edito el fichero `/etc/bacula/bacula-dir.conf`, cambiando su contenido por el siguiente (es un fichero en mi github debido a la longitud del mismo):

[bacula-dir.conf](https://github.com/robertorodriguez98/bacula/blob/main/alfa/bacula-dir.conf)

compruebo que no hay errores en el fichero de configuración:

```bash
bacula-dir -t -c /etc/bacula/bacula-dir.conf
```

Y tras eso, modifico el fichero `/etc/bacula/bacula-sd.conf`,que contiene la configuración referente a los dispositivos de almacenamiento, cambiando su contenido por el siguiente (es un fichero en mi github debido a la longitud del mismo):

[bacula-sd.conf](https://github.com/robertorodriguez98/bacula/blob/main/alfa/bacula-sd.conf)

Al igual que antes, compruebo que no hay errores en el fichero de configuración:

```bash
bacula-sd -t -c /etc/bacula/bacula-sd.conf
```

y reinicio los servicios:

```bash
systemctl restart bacula-sd.service
systemctl enable bacula-sd.service
systemctl restart bacula-director.service
systemctl enable bacula-director.service
```

## Preparación de los clientes

### Alfa

Alfa va a ser a la vez cliente y servidor, por lo que voy a instalar el cliente también en alfa:

```bash
apt install bacula-client
systemctl enable bacula-fd.service
```

Ahora modifico el fichero `/etc/bacula/bacula-fd.conf`:

```bash
Director {
  Name = alfa-dir
  Password = "bacula"
}

Director {
  Name = alfa-mon
  Password = "bacula"
  Monitor = yes
}

FileDaemon {                          # this is me
  Name = alfa-fd
  FDport = 9102                  # where we listen for the director
  WorkingDirectory = /var/lib/bacula
  Pid Directory = /run/bacula
  Maximum Concurrent Jobs = 20
  Plugin Directory = /usr/lib/bacula
  FDAddress = 10.0.0.247
}

# Send all messages except skipped files back to Director
Messages {
  Name = Standard
  director = alfa-dir = all, !skipped, !restored
}
```

Y reinicio el servicio:

```bash
systemctl restart bacula-fd.service
```


### Bravo

Instalo el cliente

```bash
sudo dnf install bacula-client
```

Y edito el fichero `/etc/bacula/bacula-fd.conf` y añado las siguientes líneas:

```bash
Director {
  Name = alfa-dir
  Password = "bacula"
}

Director {
  Name = alfa-mon
  Password = "bacula"
  Monitor = yes
}

FileDaemon {
  Name = bravo-fd
  FDport = 9102
  WorkingDirectory = /var/lib/bacula
  Pid Directory = /run/bacula
  Maximum Concurrent Jobs = 20
  Plugin Directory = /usr/lib/bacula
  FDAddress = 172.16.0.200
}

Messages {
  Name = Standard
  director = alfa-dir = all, !skipped, !restored
}
```

```bash
firewall-cmd --permanent --add-port=22/tcp
firewall-cmd --permanent --add-port=80/tcp

firewall-cmd --permanent --add-port=9101/tcp
firewall-cmd --permanent --add-port=9102/tcp
firewall-cmd --permanent --add-port=9103/tcp
firewall-cmd --reload
```


### Charlie y delta

La configuración en charlie y delta es similar, por eso la pongo junta:

```bash
sudo apt install bacula-client
```

Y edito el fichero `/etc/bacula/bacula-fd.conf`:

```bash
Director {
  Name = alfa-dir
  Password = "bacula"
}

Director {
  Name = alfa-mon
  Password = "bacula"
  Monitor = yes
}

FileDaemon {                          # this is me
  Name = delta-fd
  FDport = 9102                  # where we listen for the director
  WorkingDirectory = /var/lib/bacula
  Pid Directory = /run/bacula
  Maximum Concurrent Jobs = 20
  Plugin Directory = /usr/lib/bacula
  FDAddress = 192.168.0.3
}

# Send all messages except skipped files back to Director
Messages {
  Name = Standard
  director = alfa-dir = all, !skipped, !restored
}
```

Y reinicio el servicio:

```bash
systemctl restart bacula-fd.service
```

Ahora, con todos los cliente configurados, reinicio los servicios de bacula en alfa:

```bash
systemctl restart bacula-fd.service
systemctl restart bacula-sd.service
systemctl restart bacula-director.service
```

y hago una prueba de conexión usando la consola de bácula y la interfaz web:

```bash
bconsole
```

![bconsole](PCa4pzo.png)


![web](EWP7PH0.png)

## Nodos de almacenamiento

Ahora voy a crear los nodos de almacenamiento con bconsole

```bash
bconsole
```

![bconsole](pkpErri.png)

También se puede hacer desde la interfaz web:

![web](DKz9aUK.png)

Realizo la misma configuración para vol-semanal y vol-mensual.

Podemos ver que se han creado los volúmenes:

![web](WOVsDgp.png)

## Restauración

Voy a realizar la restauración por medio de la interfaz web. Para ello utilizo la opción de Perform restore y sigo los siguientes pasos:

![web](WpBBp3u.png)

![web2](g4kd0Ri.png)

![web3](SYrgbek.png)



Selecciono qué quiero copiar y donde:

![web5](rgz94GM.png)

![web6](DlrJT2c.png)

y que reemplace los ficheros más antiguos:

![web7](Y38EHgZ.png)

Cuando acabe puedo ver que se ha ejecutado con éxito:

![web8](6Gok1iW.png)