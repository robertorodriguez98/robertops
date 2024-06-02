---
title: "Instalación de Debian desatendida"
date: 2022-10-06T7:00:09+02:00
draft: false
media_subpath: /assets/2022-10-06-desatendida
image:
  path: featured.png
categories:
    - documentación
    - Administración de Sistemas Operativos
tags:
    - Debian
    - preseed
---

## Creación de imagen

### Descomprimimos la imagen

Vamos a utilizar la versión de debian que contiene software privativo, para, por ejemplo, tener disponibles más drivers en caso de que fueran necesarios. Tenemos que seguir los siguientes pasos:
1. Descargamos la imagen de la página de debian:
```shell
$ wget https://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/current/amd64/iso-cd/firmware-11.5.0-amd64-netinst.iso
```
2. Descomprimimos la imagen utilizando `xorriso` en el directorio `isofiles/`:
```shell
$ xorriso -osirrox on -indev firmware-11.5.0-amd64-netinst.iso -extract / isofiles/
```

### Introducimos el preseed

1. copiamos el fichero `preseed.cfg` a la raíz de la imagen:
```shell
$ sudo cp preseed.cfg isofiles/preseed.cfg
```
2. Editamos el fichero `txt.cfg` (encargado del contenido del menú inicial de instalación) para añadir una opción que utilice el `preseed` además de que cargue el idioma español:
```shell
$ sudo nano isofiles/isolinux/txt.cfg
```
```shell
label install
        menu label ^Install
        kernel /install.amd/vmlinuz
        append vga=788 initrd=/install.amd/initrd.gz --- quiet
label unattended-gnome
        menu label ^Instalacion Debian Desatendida Preseed
        kernel /install.amd/gtk/vmlinuz
        append vga=788 initrd=/install.amd/gtk/initrd.gz preseed/file=/cdrom/preseed.cfg locale=es_ES console-setup/ask_detect=false keyboard-configuration/xkb-keymap=e>
```

### Volvemos a generar la imagen

1. Como hemos alterado los ficheros que contiene la imagen, tenemos que generar un nuevo fichero `md5sum.txt`:
```shell
$ cd isofiles/
$ chmod a+w md5sum.txt
$ md5sum `find -follow -type f` > md5sum.txt
$ chmod a-w md5sum.txt
$ cd .
``` 
2. Por último cambiamos los permisos de `isolinux` y creamos la imagen nueva:
```shell
$ chmod a+w isofiles/isolinux/isolinux.bin
$ genisoimage -r -J -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o debian-preseed.iso isofiles
```

## Carga del fichero preseed.cfg desde red

### Configuración del servidor
Para la instalación desatendida cargando el `preseed` desde red, es necesario una máquina que haga el rol de servidor, teniendo un servidor `apache2` instalado. Para preparar dicha máquina seguimos los siguientes pasos: 

1. Instalamos el servidor apache en la máquina:
```bash
$ apt upgrade && apt install apache2
```
2. copiamos el fichero `preseed.cfg` previamente configurado al directorio `/var/www/html`

Tras este paso, el servidor ya está configurado y ofreciendo la configuración a la red.

### Utilización desde el cliente

Para aplicar la configuración del fichero `preseed`, iniciamos la instalación de una imagen de debian sin modificar. Para utilizarla tenemos dos opciones:
1. Utilizando línea de comandos:
    1. Pulsamos la tecla ESC para abrir la línea de comandos
    2. Introducimos el siguiente comando para acceder al fichero, donde `IP servidor` es la ip de la máquina que tiene el servidor apache:
```bash
boot: auto url=[IP servidor]/preseed.cfg
```
2. Utilizando las opciones avanzadas:
    1. Accedemos a opciones avanzadas en el menú, seguido de instalación automatizada. 
    2. Introducimos la ip del servidor con apache de la siguiente manera:
```
http://[IP servidor]/preseed.cfg
```
Tras esto, la instalación desatendida comenzará.

## Instalación basada en preseed/PXE/TFT

Para esta instalación, al igual que la anterior, es necesario que una máquina haga el rol de servidor, además en este caso tiene que tener un servidor DHCP. Para configurarla vamos a seguir los siguientes pasos. La máquina tiene que tener una red aislada sin DHCP en la que se va a conectar con los clientes

### Instalación de dnsmasq

1. Instalamos el paquete dnsmasq, encargado tanto del DHCP como del servidor TFTP
```shell
$ apt install dnsmasq
```
2. configuramos el contenido del fichero /etc/dnsmasq.conf/:
```shell
dhcp-range=192.168.100.50,192.168.100.150,255.255.255.0,12h
dhcp-boot=pxelinux.0
enable-tftp
tftp-root=/srv/tftp
```
3. En el paso anterior especificamos que se utilizara el directorio /srv/tftp/ como raíz para la transmisión por pxe; vamos a crearlo:
```shell
$ mkdir /srv/tftp/
```
4. Reiniciamos el servicio para que los cambios tengan efecto
```shell
$ systemctl restart dnsmasq
```

### Descarga de la imagen

Para instalar utilizando PXE/TFTP tenemos que utilizar una imagen de debian especial llamada netboot. Esta imagen se encuentra en la siguiente dirección: http://ftp.debian.org/debian/dists/bullseye/main/installer-amd64/current/images/netboot/netboot.tar.gz.

1. Nos desplazamos al directorio /srv/tftp/, descargamos la imagen y la descomprimimos:
```shell
$ wget http://ftp.debian.org/debian/dists/bullseye/main/installer-amd64/current/images/netboot/netboot.tar.gz
$ tar -zxf netboot.tar.gz && rm netboot.tar.gz
```

Tras este paso, el servidor ya está ofreciendo la imagen de debian a la red.

### Reglas nftables

dado que el cliente solo está conectado al servidor, no tiene ninguna conexión a internet. Por lo que el servidor, además, tiene que hacer SNAT. Para ello vamos a activar el bit de forwarding y a aplicar las siguientes reglas de nftables:
```shell
$ nft add table nat
$ nft add chain nat postrouting { type nat hook postrouting priority 100 \; }
$ nft add rule ip nat postrouting oifname "eth0" ip saddr 192.168.100.0/24 counter masquerade
$ nft list ruleset > /etc/nftables.conf
```
Si la configuración no ha persistido tras un reinicio, podemos recuperarla con:
```shell
$ nft -f /etc/nftables.conf
```

### Fichero Preseed

Para añadir el fichero preseed, tenemos dos opciones. Añadirlo a los ficheros que se están distribuyendo a través de `PXE`, o utilizar un `servidor apache`, realizándose de la misma manera que en el paso anterior.

Para utilizar el fichero `preseed.cfg` modificamos el fichero `txt.cfg` para que utilice el que estamos ofreciendo en el servidor apache:
```shell
label install
	menu label ^Install
	kernel debian-installer/amd64/linux
	append vga=788 initrd=debian-installer/amd64/initrd.gz --- quiet 
label unattended-gnome
        menu label ^Instalacion Debian Desatendida Preseed
        kernel debian-installer/amd64/linux
        append vga=788 initrd=debian-installer/amd64/initrd.gz preseed/url=192.168.100.5/preseed.txt locale=es_ES console-setup/ask_detect=false keyboard-configuration/xkb-keymap=e>
```

### Lado del cliente

La instalación desde el lado del cliente es muy similar al paso anterior. Antes de empezar, hay que añadirle una tarjeta de red que esté en la red del DHCP, y hacer que sea una opción de arranque. Una vez hecho esto, el cliente iniciará la imagen en red, y desde ahí, podemos seguir los pasos que ya sabemos para utilizar el fichero preseed.cfg
