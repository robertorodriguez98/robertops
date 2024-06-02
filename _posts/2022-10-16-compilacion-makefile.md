---
title: "Compilación de un programa en C utilizando un Makefile"
date: 2022-10-16T23:46:57+02:00
draft: False
media_subpath: /assets/2022-10-16-compilacion-makefile
image:
  path: featured.png
categories:
    - práctica
    - Administración de Sistemas Operativos
tags:
    - C
    - compilación
---

**Enunciado:** Elige el programa escrito en C que prefieras y comprueba en las fuentes que exista un fichero Makefile o Configure. Deberás compilar desde las fuentes.
Realiza los pasos necesarios para compilarlo e instálalo en tu equipo en un directorio que no interfiera con tu sistema de paquetes (/opt, /usr/local, etc.)
La corrección se hará en clase y deberás ser capaz de explicar qué son todos los ficheros que se hayan instalado y realizar una desinstalación limpia.

El programa elegido es `htop`, ya que está escrito en **C**. De momento no tiene ninguno de los ficheros requeridos, pero ejecutando el script `autogen.sh` se crea el fichero configure.

## Instalación

Para obtener las fuentes ejecutamos el siguiente comando:

```bash
apt source htop
```

ó

```bash
wget http://deb.debian.org/debian/pool/main/h/htop/htop_3.0.5.orig.tar.gz
tar -xvf htop_3.0.5.orig.tar.gz
```

### Configure

De momento el fichero no existe. Ejecutamos `autogen.sh`. Necesitaremos además el paquete `autoconf`:

```bash
sudo apt install autoconf
```

```bash
./autogen.sh
```

![ejecucion script autogen](autogen.png)
Podemos comprobar que se ha generado el fichero **configure**:
![ls del directorio de htop](ls-directorio.png)
Podemos ejecutar el fichero configure directamente. Sin embargo, de cara a una desinstalación más sencilla y a poder tener más localizados los ficheros instalados, vamos a cambiar la ruta que hay por defecto, al directorio `opt`. Se hace añadiendo la siguiente opción:

```bash
sudo mkdir /opt/htop
./configure --prefix=/opt/htop/
```

![salida de la ejecución de configure](configure.png)

En el caso de que se de algún error en la salida del comando, hay que instalar las **dependencias** indicadas, y repetir el paso anterior.


```bash
sudo apt install libncurses*
```

### Makefile

Para poder ejecutar `make` necesitamos el paquete `build-essential`, que contiene las utilidades esenciales para compilar un paquete en Debian.

```bash
sudo apt install build-essential
```

Para instalar el paquete ejecutamos:

```bash
sudo make install
sudo make clean
```

Para generar el fichero `.deb` es **necesario** que el paquete descargado sea con `apt source`, o la versión específica de debian.

o bien, para generar el fichero .deb:

instalamos las siguientes dependencias:

```bash
sudo apt install libnl-3-dev libnl-genl-3-dev libsensors-dev pkg-config debhelper-compat
# o bien con apt-get build-dep
sudo apt-get build-dep htop
```

```bash
make
dpkg-buildpackage -b
make clean
sudo dpkg -i ../htop_3.0.5-7_amd64.deb
 ```

![ejecucion de comando make](make.png)
El paquete ya está instalado. Podemos comprobar los ficheros creados en `/opt`:
![tree del directorio htop](tree-htop.png)
Entre los ficheros que aparecen, los más importantes son el propio **binario** de htop, y el **manual**.
Para poder utilizar el comando la terminal tenemos que añadirlo al **PATH**. Para hacerlo, añadimos la siguiente línea al fichero `.bashrc`:

```bash
export PATH="/opt/htop/bin:$PATH"
```

### Manual

Ya que lo hemos instalado en un directorio personal, no se ha creado el manual. Para hacerlo tenemos que crear un enlace simbólico:

```bash
sudo mkdir /usr/local/man/man1
sudo ln -s /opt/htop/share/man/man1/* /usr/local/man/man1/
```

## Desinstalación

Para desinstalar el paquete vamos a utilizar otra vez el comando make, esta vez con la opción `uninstall`:

```bash
sudo make uninstall
```

![ejecucion de make uninstall](desinstalar.png)
Tras eso, comprobamos si queda algo en la ubicación de la instalación:
![estructura residual](estructura.png)
la estructura de carpetas no se ha borrado, la borramos de manera manual.
Por último, hay que eliminar la línea de `.bashrc` que añade la ruta al `PATH` y eliminar el enlace simbólico:

```bash
sudo rm /usr/local/man/man1/htop.1 
```
