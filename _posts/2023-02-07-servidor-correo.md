---
title: "Práctica: Servidor de correos"
date: 2023-02-07T01:57:14+01:00
draft: false
media_subpath: /assets/2023-02-07-servidor-correo
image:
  path: featured.png
categories:
    - documentación
    - Servicios de Red e Internet
tags:
    - correo
    - autoalojado
    - vps
---

## Gestión de correo desde el servidor

### Tarea 1


Documenta una prueba de funcionamiento, donde envíes desde tu servidor local al exterior. Muestra el log donde se vea el envío. Muestra el correo que has recibido. Muestra el registro SPF.


Creo las siguientes entradas en el DNS  de mi dominio:

![MX](https://i.imgur.com/izykpPC.png)

Donde hay un registro MX que apunta a mail.admichin.es, que a su vez es un registro A que apunta a la IP de mi servidor. Además, hay un registro SPF que apunta a la ip de la máquina.

Además, configuro resolución inversa en la configuración de la VPS:

![Reverse](https://i.imgur.com/Q8x5DC1.png)

Ahora, en la VPS instalo los siguientes paquetes:

```bash
apt update
apt install postfix bsd-mailx -y
```

Durante la configuración, selecciono **Internet Site** y **admichin.es**.

Envío un correo a mi cuenta personal:

```bash
mail robertorodriguezmarquez98@gmail.com
Subject: Prueba de funcionamiento
Hola buenos días
Cc:
```

Vemos el log de postfix:

```bash
tail /var/log/mail.log
```

![Log](https://i.imgur.com/lii209w.png)

Y el correo recibido:

![Correo](https://i.imgur.com/FWNO7aB.png)

### Tarea 2


Documenta una prueba de funcionamiento, donde envíes un correo desde el exterior (gmail, hotmail,…) a tu servidor local. Muestra el log donde se vea el envío. Muestra cómo has leído el correo. Muestra el registro MX de tu dominio.


Ahora envío un correo desde mi cuenta personal a mi servidor:

![Correo](https://i.imgur.com/FWNO7aB.png)

Y compruebo que el correo ha llegado a mi servidor:

![Correo](https://i.imgur.com/JWSTUmj.png)
![Correo](https://i.imgur.com/D0xKQDi.png)

Y el log de postfix:

![Log](https://i.imgur.com/pAWEPrP.png)

## Uso de alias y redirecciones

### Tarea 3


**Usos de alias y redirecciones**. Vamos a comprobar como los procesos del servidor pueden mandar correos para informar sobre su estado. Por ejemplo cada vez que se ejecuta una tarea cron podemos enviar un correo informando del resultado. Normalmente estos correos se mandan al usuario `root` del servidor, para ello:

```bash
 crontab -e
```

E indico donde se envía el correo:

```bash
MAILTO=root
```

Puedes poner alguna tarea en el cron para ver como se mandan correo.

Posteriormente usando alias y redirecciones podemos hacer llegar esos correos a nuestro correo personal.

Configura el cron para enviar correo al usuario root. Comprueba que están llegando esos correos al root. Crea un nuevo alias para que se manden a un usuario sin privilegios. Comprueban que llegan a ese usuario. Por último crea una redirección para enviar esos correo a tu correo personal (gmail,hotmail,…).


Voy a crear un script que muestre la fecha y el espacio en el disco. Lo guardo en `/root/script-espacio.sh`:

```bash
#!/bin/bash

echo "##################################"
echo "Fecha y hora: $(date)"
echo "##################################"
echo "Espacio en el disco:"
df -h
```

Ahora creamos la tarea de cron para que se ejecute cada 5 minutos:

```bash
crontab -e
```

Y añadimos las siguientes líneas:

```bash
MAILTO = root

*/5 * * * * /root/script-espacio.sh
```

Cuando pasan 5 minutos, recibimos el correo:

![Correo](https://i.imgur.com/XVtl86N.png)

Ahora voy a crear un alias para que se envíen los correos a un usuario sin privilegios (en este caso, calcetines), editando el fichero `/etc/aliases`:

```bash
root: calcetines
```

Y ejecuto el comando `newaliases` para que se actualicen los alias.

Ahora, cuando pasen 5 minutos, recibimos el correo en el usuario sin privilegios:

![Correo](https://i.imgur.com/aogu98o.png)

Ahora voy a crear una redirección para que se envíen los correos a mi correo personal, editando el fichero `/home/calcetines/.forward`:

```bash
robertorodriguezmarquez98@gmail.com
```

Y ahora, cuando pasen 5 minutos, recibimos el correo en mi correo personal:

![Correo](https://i.imgur.com/UdaG5gg.png)

## Para asegurar el envío

### Tarea 4


Configura de manera adecuada DKIM es tu sistema de correos. Comprueba el registro DKIM en la página https://mxtoolbox.com/dkim.aspx. Configura postfix para que firme los correos que envía. Manda un correo y comprueba la verificación de las firmas en ellos.
}

Voy a instalar el paquete `opendkim`:

```bash
apt install opendkim opendkim-tools -y
```

En el fichero `/etc/opendkim.conf`, edito las siguientes líneas:

```bash
Domain                  admichin.es
Selector                default
KeyFile                 /etc/opendkim/keys/admichin.es/default.private
#Socket                 local:/run/opendkim/opendkim.sock
Socket                  local:/var/spool/postfix/opendkim/opendkim.sock
PidFile                 /run/opendkim/opendkim.pid
TrustAnchorFile         /usr/share/dns/root.key
```

Ahora añado el socket en el fichero `/etc/default/opendkim`.

Tras eso, en el fichero `/etc/postfix/main.cf`, añado las siguientes líneas:

```bash
milter_default_action = accept
milter_protocol = 6
smtpd_milters = local:opendkim/opendkim.sock
non_smtpd_milters = $smtpd_milters
```

Ahora genero los ficheros de claves:

```bash
mkdir /etc/opendkim/keys/admichin.es
cd /etc/opendkim/keys/admichin.es
opendkim-genkey -b 2048 -d admichin.es -D /etc/opendkim/keys/admichin.es -s default -v
```

Ahora, utilizando el contenido de `/etc/opendkim/keys/admichin.es/default.txt`, añado un registro TXT en el dominio `admichin.es`:

![Registro](https://i.imgur.com/rWLIaWm.png)

Reinicio los servicios:

```bash
systemctl restart opendkim postfix
```

Ahora, cuando envío un correo, se añade la firma DKIM:

![Correo](https://i.imgur.com/SjhdRvn.png)

Finalmente, compruebo la verificación de la firma en la página **mxtoolbox**:

![Verificación](https://i.imgur.com/leht5mi.png)

## Para luchar contra el spam

## Gestión de correos desde un cliente

### Tarea 8


Configura el buzón de los usuarios de tipo Maildir. Envía un correo a tu usuario y comprueba que el correo se ha guardado en el buzón Maildir del usuario del sistema correspondiente. Recuerda que ese tipo de buzón no se puede leer con la utilidad mail.


Voy a cambiar el tipo de buzón de los usuarios, editando el fichero `/etc/postfix/main.cf`:

```bash
home_mailbox = Maildir/
```

Ahora instalamos el cliente mutt para poder leer los correos:

```bash
apt install mutt -y
systemctl restart postfix
```

Tengo que hacer la siguiente configuración en cada usuario:

```bash
nano ~/.muttrc
```

```bash
set mbox_type=Maildir
set mbox="~/Maildir"
set folder="~/Maildir"
set spoolfile="~/Maildir"
set record="+.Sent"
set postponed="+.Drafts"
set mask="!^\\.[^.]"
```

Podemos ver el contenido del directorio `Maildir`:

![Directorio](https://i.imgur.com/xJmTIsK.png)

Ahora, cuando envío un correo, se guarda en el buzón Maildir del usuario del sistema correspondiente, y lo podemos leer con mutt:

![Correo](https://i.imgur.com/mCg6V9I.png)

### Tarea 9

Instala configura dovecot para ofrecer el protocolo IMAP. Configura dovecot de manera adecuada para ofrecer autentificación y cifrado.


Instalo dovecot:

```bash
apt install dovecot-imapd -y
```

Modifico el fichero `/etc/dovecot/conf.d/10-ssl.conf` para añadir el certificado que generamos con certbot al crear la página,  modificando las siguientes líneas:

```bash
ssl_cert = </etc/letsencrypt/live/admichin.es-0001/fullchain.pem
ssl_key = </etc/letsencrypt/live/admichin.es-0001/privkey.pem
```

Ahora cambiamos la localización de los mailbox en el fichero `/etc/dovecot/conf.d/10-mail.conf`:

```bash
mail_location = maildir:~/Maildir
```

### Tarea 10


Instala un webmail (roundcube, horde, rainloop) para gestionar el correo del equipo mediante una interfaz web. Muestra la configuración necesaria y cómo eres capaz de leer los correos que recibe tu usuario.


Voy a instalar **roundcube** utilizando docker:

```bash
apt install docker.io -y
```

Creo una entrada de tipo CNAME con el nombre webmail:

![CNAME](https://i.imgur.com/dLpPCex.png)

Ahora vamos a crear la configuración  en un directorio que montaremos posteriormente por medio de bind mount en el docker;

```bash
mkdir /root/cuboredondo
nano -cl /root/cuboredondo/custom.inc.php
```

```php
<?php
$config['mail_domain'] = array(
    'mail.admichin.es' => 'admichin.es'
);
?>
```

Ahora creo el contenedor de docker:

```bash
docker run -d --name docker-cuboredondo \
-v /root/cuboredondo/:/var/roundcube/config/ \
-e ROUNDCUBEMAIL_DEFAULT_HOST=ssl://mail.admichin.es \
-e ROUNDCUBEMAIL_SMTP_SERVER=ssl://mail.admichin.es \
-e ROUNDCUBEMAIL_SMTP_PORT=465 \
-e ROUNDCUBEMAIL_DEFAULT_PORT=993 \
-p 8001:80 \ 
roundcube/roundcubemail
```

o en una sola linea:

```bash
docker run -d --name docker-cuboredondo -v /root/cuboredondo/:/var/roundcube/config/ -e ROUNDCUBEMAIL_DEFAULT_HOST=ssl://mail.admichin.es -e ROUNDCUBEMAIL_SMTP_SERVER=ssl://mail.admichin.es -e ROUNDCUBEMAIL_SMTP_PORT=465 -e ROUNDCUBEMAIL_DEFAULT_PORT=993 -p 8001:80 roundcube/roundcubemail
```

Ahora creo el virtualhost para el dominio en `/etc/nginx/sites-available/webmail.admichin.es`:

```bash
server {
        listen 80;
        listen [::]:80;

        server_name webmail.admichin.es;

        return 301 https://$host$request_uri;
}

server {
        listen 443 ssl http2;
        listen [::]:443 ssl http2;

        ssl    on;
        ssl_certificate /etc/letsencrypt/live/admichin.es-0001/fullchain.pem;
        ssl_certificate_key     /etc/letsencrypt/live/admichin.es-0001/privkey.pem;

        index index.html index.php index.htm index.nginx-debian.html;

        server_name webmail.admichin.es;

        location / {
                proxy_pass http://localhost:8001;
                include proxy_params;
        }
}
```

Ahora activo el sitio y reinicio nginx:

```bash
ln -s /etc/nginx/sites-available/webmail.admichin.es /etc/nginx/sites-enabled/
systemctl restart nginx
```

Ahora podemos acceder a la instancia de roundcube desde el navegador:

![Roundcube](https://i.imgur.com/CEWcKuI.png)

Como se puede ver acabo de recibir el correo del ejercicio de la tarea del cron. Ahora un correo enviado desde fuera:

![Correo enviado desde fuera](https://i.imgur.com/bqHtnNH.png)

### Tarea 11


Configura de manera adecuada postfix para que podamos mandar un correo desde un cliente remoto. La conexión entre cliente y servidor debe estar autentificada con SASL usando dovecor y además debe estar cifrada. Para cifrar esta comunicación puedes usar dos opciones:

* **ESMTP + STARTTLS**: Usando el puerto 567/tcp enviamos de forma segura el correo al servidor.
* **SMTPS**: Utiliza un puerto no estándar (465) para SMTPS (Simple Mail Transfer Protocol Secure). No es una extensión de smtp. Es muy parecido a HTTPS.

Elige una de las opciones anterior para realizar el cifrado. Y muestra la configuración de un cliente de correo (evolution, thunderbird, …) y muestra como puedes enviar los correos.


Usaré los mismos certificados que he generado antes para cifrar los emails que envío y recibo. Para ello, modifico la configuración de postfix en `/etc/postfix/main.cf`:

```bash
smtpd_tls_cert_file = /etc/letsencrypt/live/admichin.es-0001/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/admichin.es-0001/privkey.pem

smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_authenticated_header = yes
broken_sasl_auth_clients = yes
```

Ahora edito `/etc/postfix/master.cf`:

```bash
submission inet n       -       y       -       -       smtpd
  -o content_filter=spamassassin
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=$mua_client_restrictions
  -o smtpd_helo_restrictions=$mua_helo_restrictions
  -o smtpd_sender_restrictions=$mua_sender_restrictions
  -o smtpd_recipient_restrictions=
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=$mua_client_restrictions
  -o smtpd_helo_restrictions=$mua_helo_restrictions
  -o smtpd_sender_restrictions=$mua_sender_restrictions
  -o smtpd_recipient_restrictions=
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
```

Le indico a dovecot como debe realizar la auntentificación en el fichero `/etc/dovecot/conf.d/10-master.conf`:

```bash
service auth {
  ...
  # Postfix smtp-auth
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
  }
  ...
}
```

Ahora hay que abrir los puertos 465 y 993 en la vps. Tras eso, reiniciamos el servicio:

```bash
systemctl restart postfix dovecot
```

Ahora configuramos el cliente de correo **evolution**:

![Configuración de evolution](https://i.imgur.com/pdVsGVt.png)
![Configuración de evolution](https://i.imgur.com/Asvo17x.png)

Tras configurarlo probamos la recepción de un correo:

![Correo recibido](https://i.imgur.com/4g08tu3.png)

Y el envío:

![Correo enviado](https://i.imgur.com/ZBCNpp7.png)
![Correo enviado](https://i.imgur.com/jbV8Ojo.png)


### Tarea 12


Configura el cliente webmail para el envío de correo. Realiza una prueba de envío con el webmail.


Esta tarea consiste en poder enviar correos desde el cliente roundcube, y se han realizado las configuraciones necesarias en la tarea 10. Ahora solo queda probarlo:

![Correo enviado desde roundcube](https://i.imgur.com/CGQ8zuf.png)
![Correo enviado desde roundcube](https://i.imgur.com/miQ63i6.png)

## Comprobación final

### Tarea 13


 Prueba de envío de correo. En esta [página](https://www.mail-tester.com/) tenemos una herramienta completa y fácil de usar a la que podemos enviar un correo para que verifique y puntúe el correo que enviamos. Captura la pantalla y muestra la puntuación que has sacado.


Enviamos un correo para comprobar la puntuación:

![Correo enviado para comprobar la puntuación](https://i.imgur.com/pt2pp6m.png)
![Correo enviado para comprobar la puntuación](https://i.imgur.com/X5klV3K.png)