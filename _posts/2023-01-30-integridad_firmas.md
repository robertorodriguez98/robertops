---
title: "Integridad, firmas y autenticación"
date: 2023-01-30T09:16:26+01:00
draft: false
media_subpath: /assets/2023-01-30-integridad_firmas
image:
  path: featured.png
categories:
    - documentación
    - Seguridad y Alta Disponibilidad
tags:
    - criptografía
    - gnupg
---

## Tarea 1: Firmas electrónicas

1. **Manda un documento y la firma electrónica del mismo a un compañero. Verifica la firma que tu has recibido.**

```bash
echo "DOCUMENTO CIFRADO SECRETO" > documento_rober.txt\n
gpg --output firmarober.sig --detach-sig documento_rober.txt
```

Envío los ficheros por correo.

2. **¿Qué significa el mensaje que aparece en el momento de verificar la firma?**

![Firma](https://i.imgur.com/dOFJJTl.png)

Significa que, aunque el fichero está firmado por esa firma, no se puede asegurar que la firma pertenezca a la persona que dice ser.

3. **Vamos a crear un anillo de confianza entre los miembros de nuestra clase, para ello.**
    * Tu clave pública debe estar en un servidor de claves
    * Escribe tu fingerprint en un papel y dárselo a tu compañero, para que puede descargarse tu clave pública.
    * Te debes bajar al menos tres claves públicas de compañeros. Firma estas claves.
    * Tu te debes asegurar que tu clave pública es firmada por al menos tres compañeros de la clase.
    * Una vez que firmes una clave se la tendrás que devolver a su dueño, para que otra persona se la firme.
    * Cuando tengas las tres firmas sube la clave al servidor de claves y rellena tus datos en la tabla Claves públicas PGP 2020-2021
    * Asegurate que te vuelves a bajar las claves públicas de tus compañeros que tengan las tres firmas.

4. **Muestra las firmas que tiene tu clave pública.**

Listamos las firmas con el comando `gpg --list-sigs`

![Firmas](https://i.imgur.com/LnWbJLH.png)

5. **Comprueba que ya puedes verificar sin “problemas” una firma recibida por una persona en la que confías.**

Como se puede ver en la imagen anterior, nuestra firma está verificada por **Antonio**, y viceversa. Por lo que podemos verificar sin problemas un documento firmado por **Antonio**.

![Verificación](https://i.imgur.com/LnLceFT.png)

6. **Comprueba que puedes verificar con confianza una firma de una persona en las que no confías, pero sin embargo si confía otra persona en la que tu tienes confianza total.**

Ahora, vamos a utilizar un fichero firmado por **María Jesús**, en la que no confiamos directamente, pero en la que sí tiene confianza plena **Antonio**:

![Verificación 2](https://i.imgur.com/dzHItTJ.png)

## Tarea 3: Integridad de ficheros

Para validar el contenido de la imagen CD, solo asegúrese de usar la herramienta apropiada para sumas de verificación. Para cada versión publicada existen archivos de suma de comprobación con algoritmos fuertes (SHA256 y SHA512); debería usar las herramientas sha256sum o sha512sum para trabajar con ellos.

1. **Verifica que el contenido del hash que has utilizado no ha sido manipulado, usando la firma digital que encontrarás en el repositorio. Puedes encontrar una guía para realizarlo en este artículo: How to verify an authenticity of downloaded Debian ISO images**

```bash
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.6.0-amd64-netinst.iso
wget https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS
sha256sum -c SHA256SUMS 2> /dev/null | grep netinst
```

![Verificación de hash](https://i.imgur.com/aAHo0GB.png)

## Tarea 4: Integridad y autenticidad

Busca información sobre **apt secure** y responde las siguientes preguntas:

1. **¿Qué software utiliza apt secure para realizar la criptografía asimétrica?**

Utiliza **GnuPG** para realizar la criptografía asimétrica.

2. **¿Para que sirve el comando apt-key? ¿Qué muestra el comando apt-key list?**

El comando `apt-key` sirve para administrar las claves de los repositorios de paquetes. El comando `apt-key list` muestra las claves de los repositorios de paquetes.

3. **En que fichero se guarda el anillo de claves que guarda la herramienta apt-key?**

El anillo de claves se guarda en el fichero `/etc/apt/trusted.gpg`.

4. **¿Qué contiene el archivo Release de un repositorio de paquetes?. ¿Y el archivo Release.gpg?. Puedes ver estos archivos en el repositorio http://ftp.debian.org/debian/dists/Debian10.1/. Estos archivos se descargan cuando hacemos un apt update.**

El archivo `Release` contiene la lista de paquetes que contiene el repositorio de paquetes. El archivo `Release.gpg` contiene la firma digital del archivo `Release`.

5. **Explica el proceso por el cual el sistema nos asegura que los ficheros que estamos descargando son legítimos.**

El sistema nos asegura que los ficheros que estamos descargando son legítimos mediante la verificación de la firma digital del fichero `Release` que se encuentra en el repositorio de paquetes.

6. **añade de forma correcta el repositorio de virtualbox añadiendo la clave pública de virtualbox como se indica en la documentación.**

Se hace con los siguientes comandos:

```bash
echo "deb https://download.virtualbox.org/virtualbox/debian buster contrib" >> /etc/apt/sources.list
wget -q https://www.virtualbox.org/download/oracle\_vbox\_2016.asc -O- | apt-key add -
wget -q https://www.virtualbox.org/download/oracle\_vbox.asc -O- | apt-key add -
```

Tras esto, se puede instalar virtualbox con el comando `apt install virtualbox`.

## Tarea 5: Autentificación: ejemplo SSH

1. **Explica los pasos que se producen entre el cliente y el servidor para que el protocolo cifre la información que se transmite? ¿Para qué se utiliza la criptografía simétrica? ¿Y la asimétrica?**

Los pasos que se producen entre el cliente y el servidor para que el protocolo cifre la información que se transmite son los siguientes:

* Se lleva a cabo un 'handshake' (apretón de manos) encriptado para que el cliente pueda verificar que se está comunicando con el servidor correcto
* La capa de transporte de la conexión entre el cliente y la máquina remota es encriptada mediante un código simétrico
* El cliente se autentica ante el servidor.
* El cliente remoto interactua con la máquina remota sobre la conexión encriptada.

La criptografía simétrica se utiliza para encriptar la información que se transmite entre el cliente y el servidor. La criptografía asimétrica se utiliza para autentificar al cliente y al servidor.


2. **Explica los dos métodos principales de autentificación: por contraseña y utilizando un par de claves públicas y privadas.**

Los dos métodos principales de autentificación son:

* Por contraseña: el cliente envía la contraseña al servidor para que este pueda autentificar al cliente.
* Por par de claves públicas y privadas: el cliente envía su clave pública al servidor para que este pueda autentificar al cliente. El cliente envía su clave privada al servidor para que este pueda autentificar al cliente.

3. **En el cliente para que sirve el contenido que se guarda en el fichero ~/.ssh/know_hosts?**

El contenido que se guarda en el fichero ~/.ssh/know_hosts sirve para que el cliente pueda autentificar al servidor.

4. **¿Qué significa este mensaje que aparece la primera vez que nos conectamos a un servidor?**
```bash
 $ ssh debian@172.22.200.74
 The authenticity of host '172.22.200.74 (172.22.200.74)' can't be established.
 ECDSA key fingerprint is SHA256:7ZoNZPCbQTnDso1meVSNoKszn38ZwUI4i6saebbfL4M.
 Are you sure you want to continue connecting (yes/no)? 
```

Implica que la conexión es nueva y que el cliente no tiene guardada la clave pública del servidor. Por lo tanto, el cliente no puede autentificar al servidor. El cliente pregunta al usuario si quiere continuar con la conexión.

5. **En ocasiones cuando estamos trabajando en el cloud, y reutilizamos una ip flotante nos aparece este mensaje:**
```bash
 $ ssh debian@172.22.200.74
 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 @    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
 Someone could be eavesdropping on you right now (man-in-the-middle attack)!
 It is also possible that a host key has just been changed.
 The fingerprint for the ECDSA key sent by the remote host is
 SHA256:W05RrybmcnJxD3fbwJOgSNNWATkVftsQl7EzfeKJgNc.
 Please contact your system administrator.
 Add correct host key in /home/jose/.ssh/known_hosts to get rid of this message.
 Offending ECDSA key in /home/jose/.ssh/known_hosts:103
   remove with:
   ssh-keygen -f "/home/jose/.ssh/known_hosts" -R "172.22.200.74"
 ECDSA host key for 172.22.200.74 has changed and you have requested strict checking.
```

Significa que la clave pública que teníamos asociada a esa dirección IP ha cambiado. Por lo tanto, el cliente no puede autentificar al servidor. Por lo que podría implicar  que se está suplantando su identidad. Si aún así queremos continuar, hay que ejecutar el comando `ssh-keygen -f "/home/jose/.ssh/known_hosts" -R "172.22.200.74"`

6. **¿Qué guardamos y para qué sirve el fichero en el servidor ~/.ssh/authorized_keys?**

En ese fichero se guardan las claves públicas de los clientes que pueden acceder al servidor. Sirve para que el servidor pueda autentificar a los clientes.