---
title: "Introducción a OpenLDAP"
date: 2023-01-25T13:47:32+01:00
draft: false
media_subpath: /assets/2023-01-25-introduccion-ldap
image:
  path: featured.png
categories:
    - documentación
    - Administración de Sistemas Operativos
tags:
    - LDAP
    - OpenStack
---

El protocolo **LDAP** es muy utilizado actualmente por empresa que apuestan por el software libre al utilizar distribuciones de Linux para ejercer las funciones propias de un **directorio activo** en el que se gestionarán las credenciales y permisos de los trabajadores y estaciones de trabajo en redes LAN corporativas en conexiones cliente/servidor.


Realiza la instalación y configuración básica de OpenLDAP en alfa,utilizando como base el nombre DNS asignado. Deberás crear un usuario llamado prueba y configurar una máquina cliente basada en Debian y Rocky para que pueda validarse en servidor ldap configurado anteriormente con el usuario prueba.



## Servidor

### Instalación de OpenLDAP

Instalaremos OpenLDAP en el servidor alfa, para ello ejecutaremos los siguientes comandos:

```bash
apt update
apt install slapd
```

Durante la instalación nos pedirá que introduzcamos la contraseña de administrador del directorio:

![Instalación de OpenLDAP](https://i.imgur.com/NaNjKFA.png)

Una vez instalado con el comando `netstat -tulpn` comprobaremos que el servicio está escuchando en el puerto 389:

![Instalación de OpenLDAP](https://i.imgur.com/KGi2Vz6.png)

Ahora, utilizando el binario `ldapsearch` incluido en el paquete `ldap-utils` podemos buscar sobre el directorio:

```bash
ldapsearch -x -b "dc=roberto,dc=gonzalonazareno,dc=org"
```

![ldapsearch1](https://i.imgur.com/FgmXMPY.png)

### Configuración de OpenLDAP

![esquemaLDAP](https://i.imgur.com/qRgLvAz.png)

Para lograr una mejor estructura, la información suele organizarse en forma de **ramas** de las que cuelgan objetos similares (por ejemplo, una rama para usuarios y otra para grupos). Organizar de esta manera la estructura nos aporta también una mayor agilidad en las búsquedas, así como una gestión más eficiente sobre los permisos. Cada rama se denomina **organizational unit** (OU) y cada objeto que cuelga de ella se denomina **entry**.

ara definir dichos objetos, haremos uso de un fichero con extensión `.ldif`, en este caso he creado el fichero `unidades.ldif` con el siguiente contenido:

```ldif
dn: ou=Personas,dc=roberto,dc=gonzalonazareno,dc=org
objectClass: organizationalUnit
ou: Personas 

dn: ou=Grupos,dc=roberto,dc=gonzalonazareno,dc=org
objectClass: organizationalUnit
ou: Grupos
```

Para activar el fichero de configuración, ejecutaremos el siguiente comando:

```bash
ldapadd -x -D "cn=admin,dc=roberto,dc=gonzalonazareno,dc=org" -f unidades.ldif -W
```

![ldapadd](https://i.imgur.com/QlLeqHB.png)

Ahora, podemos comprobar que se ha creado las ramas `Personas` y `Grupos`:

```bash
ldapsearch -x -b "dc=roberto,dc=gonzalonazareno,dc=org"
```

![ldapsearch2](https://i.imgur.com/ypKuRlq.png)

Podemos borrar los objetos creados con el comando `ldapdelete`:

```bash
ldapdelete -x -D 'cn=admin,dc=roberto,dc=gonzalonazareno,dc=org' -W ou=Personas,dc=roberto,dc=gonzalonazareno,dc=org
ldapdelete -x -D 'cn=admin,dc=roberto,dc=gonzalonazareno,dc=org' -W ou=Grupos,dc=roberto,dc=gonzalonazareno,dc=org
```

Ahora vamos a crear un grupo llamado prueba en el fichero `grupos.ldif`:

```ldif
dn: cn=prueba,ou=Grupos,dc=roberto,dc=gonzalonazareno,dc=org
objectClass: posixGroup
gidNumber: 2001
cn: prueba
```

Para activar el fichero de configuración, ejecutaremos el siguiente comando:

```bash
ldapadd -x -D 'cn=admin,dc=roberto,dc=gonzalonazareno,dc=org' -W -f grupos.ldif
```

Ejecutando el comando `ldapsearch` podemos comprobar que se ha creado el grupo:

![ldapadd2](https://i.imgur.com/MZxmh26.png)

### Creación del usuario

Ahora vamos a crear un usuario llamado *prueba*. Antes de crearlo, vamos a ejecutar el comando `slappasswd` para crear una contraseña cifrada para el usuario:

![slappasswd](https://i.imgur.com/RrnHM66.png)

Ahora, vamos a crear el usuario en el fichero `usuarios.ldif`:

```ldif
dn: uid=prueba,ou=Personas,dc=roberto,dc=gonzalonazareno,dc=org
objectClass: posixAccount
objectClass: inetOrgPerson
objectClass: person
cn: prueba
uid: prueba
uidNumber: 2001
gidNumber: 2001
homeDirectory: /nfs/prueba
loginShell: /bin/bash
userPassword: {SSHA}sDPbVb9gQ37YaNSg5nPyIe776dmlU2bq
sn: prueba
mail: prueba@gmail.com
givenName: prueba
```

Para activar el fichero de configuración, ejecutaremos el siguiente comando:

```bash
ldapadd -x -D 'cn=admin,dc=roberto,dc=gonzalonazareno,dc=org' -W -f usuarios.ldif
```

Ejecutando el comando `ldapsearch` podemos comprobar que se ha creado el usuario:

![ldapadd3](https://i.imgur.com/9pq9gxy.png)

### Configuración de NFS

Ahora vamos a configurar el servidor NFS para que pueda compartir el directorio `/nfs` con los clientes.

Primero vamos a crear el directorio `/nfs/prueba` y le vamos a dar permisos al usuario `prueba`:

```bash
mkdir /nfs/prueba
chown 2001:2001 /nfs/prueba
```

Ahora vamos a editar el fichero `/etc/exports` y añadir la siguiente línea, que permite que el usuario `prueba` pueda acceder al directorio `/nfs/prueba`:

```bash
/nfs       *(rw,fsid=0,subtree_check)
```

Ahora vamos a reiniciar el servicio NFS:

```bash
systemctl restart nfs-server
```

### Configuración final del servidor LDAP

Ahora vamos a configurar el servidor LDAP para que sea capaz de resolver nombres de grupos y de usuarios, consultar información a un directorio LDAP, identificarse o cachear la resolución de nombres.

Para ello, instalamos los siguientes paquetes:

```bash
apt install libpam-ldapd nscd libnss-ldap
```

Durante la instalación, dejamos los valores por defecto menos en las siguientes preguntas:

![ldapinstall](https://i.imgur.com/9xawQHF.png)
![ldapinstall2](https://i.imgur.com/mnPntoB.png)

Como se indica al final de la instalación, vamos a editar el fichero `/etc/nsswitch.conf` y añadir las siguientes líneas:

```bash
passwd:         files ldap
group:          files ldap
shadow:         files ldap
gshadow:        files ldap

hosts:          files dns mymachines
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
```

Reiniciamos el servicio `nscd`:

```bash
systemctl restart nscd
```

Ahora con el comando `id prueba` podemos comprobar que se resuelven los nombres:

![id](https://i.imgur.com/ucsbVhG.png)

Finalmente podemos iniciar sesión con el comando `login prueba`:

![login](https://i.imgur.com/zxXslPM.png)

## Cliente Ubuntu

Instalamos el siguiente paquete:

```bash
apt install ldap-utils
```

Ahora vamos a editar el fichero `/etc/ldap/ldap.conf` y añadir las siguientes líneas:

```bash
BASE dc=roberto,dc=gonzalonazareno,dc=org
URI ldap://alfa.roberto.gonzalonazareno.org
```

Después de esto, con el siguiente comando comprobamos que funciona correctamente:

```bash
ldapsearch -x -b "dc=roberto,dc=gonzalonazareno,dc=org"
```

![ldapsearch](https://i.imgur.com/FKUMW0Q.png)

Ahora vamos a instalar los paquetes para las resoluciones:

```bash
apt install libnss-ldap libpam-ldapd nscd
```

La instalación es similar a la del sevidor, dejando valores por defecto y cambiando los mismos, además de añadir un usuario sin privilegios.

Como se indica al final de la instalación, vamos a editar el fichero `/etc/nsswitch.conf` y añadir las siguientes líneas:

```bash
passwd:         files systemd ldap
group:          files systemd ldap
shadow:         files ldap 
gshadow:        files ldap

hosts:          files dns
networks:       files

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
```

Reiniciamos el servicio `nscd`:

```bash
systemctl restart nscd
```

### NFS

Ahora vamos a instalar el paquete `nfs-common`:

```bash
apt install nfs-common
```

Activamos el servicio

```bash
systemctl start nfs-client.target & systemctl enable nfs-client.target
```

Ahora vamos a crear los directorios que vamos a montar:

```bash
mkdir -p /home/nfs/prueba
chown 2001:2001 /home/nfs/prueba
```

Ahora vamos a montar la carpeta mediante NFS. Primero, cargamos el módulo

```bash
modprobe nfs
```

Con la siguiente línea se carga automáticamente:

```bash
echo NFS | tee -a /etc/modules
```

Y vamos a hacer un montaje mediante SystemD a través del fichero `/etc/systemd/system/home-nfs.mount`:

```bash
[Unit]
Description=script de montaje NFS
Requires=network-online.target
After=network-online.target
[Mount]
What=192.168.0.1:/nfs
Where=/home/nfs
Options=_netdev,auto
Type=nfs
[Install]
WantedBy=multi-user.target
```

Y lo activamos:

```bash
systemctl daemon-reload
systemctl start home-nfs.mount
systemctl enable home-nfs.mount
```

Tras esto, ya podremos entrar correctamente con `login prueba`. Podemos comprobar como los ficheros creados en el servidor se ven reflejados en el cliente:

![nfs](https://i.imgur.com/J1lCNBZ.png)
