---
title: "Informática forense"
date: 2023-02-08T18:50:12+01:00
draft: false
media_subpath: /assets/2023-02-08-informatica-forense
image:
  path: featured.png
categories:
    - documentación
    - Seguridad y Alta Disponibilidad
tags:
    - Forense
    - Autopsy
---

## Enunciado

La informática forense es el conjunto de técnicas que nos permite obtener la máxima información posible tras un incidente o delito informático.

En esta práctica, realizarás la fase de toma de evidencias y análisis de las mismas sobre una máquina Linux y otra Windows. Supondremos que pillamos al delincuente in fraganti y las máquinas se encontraban encendidas. Opcionalmente, podéis realizar el análisis de un dispositivo Android.

Sobre cada una de las máquinas debes realizar un volcado de memoria y otro de disco duro, tomando las medidas necesarias para certificar posteriormente la cadena de custodia.



## Apartado A. Máquina Windows

### Volcado de memoria

Para realizar el volcado de memoria he usado la herramienta **FTK Imager**, que permite realizar volcados de disco y memoria. Para ello hago lo siguiente. Utilizo las siguientes opciones:

![ftk4](https://i.imgur.com/tD6w8MG.png)

Ahora, para analizar los datos, utilizo **Volatility** en mi máquina debian; para ello, especifico el fichero que he creado con FTK Imager al utilizar los comandos.

#### 1. Procesos en ejecución

Uso el comando `pslist` para ver los procesos en ejecución:

```bash
python vol.py -f "/media/roberto/usb/memdump.mem" windows.pslist.PsList
```

![vol1](https://i.imgur.com/tMhTGFN.png)

#### 2. Servicios en ejecución

Uso el comando `getservicesids` para ver los servicios en ejecución:

```bash
python vol.py -f "/media/roberto/usb/memdump.mem" windows.getservicesids.GetServiceSIDs
```

![vol2](https://i.imgur.com/BZjmc2d.png)

#### 3. Puertos abiertos

Uso el comando `netstat` para ver los puertos abiertos:

```bash
python vol.py -f "/media/roberto/usb/memdump.mem" windows.netstat.NetStat 
```

![vol3](https://i.imgur.com/DnH0We9.png)

#### 4. Conexiones establecidas por la máquina

Uso el comando `netscan` para ver las conexiones establecidas por la máquina:

```bash
python vol.py -f "/media/roberto/usb/memdump.mem" windows.netscan.NetScan
```

![vol4](https://i.imgur.com/7ZrLSg4.png)

#### 5. Sesiones de usuario establecidas remotamente

Uso el comando `sessions` para ver las sesiones de usuario establecidas remotamente:

```bash
python vol.py -f "/media/roberto/usb/memdump.mem" windows.sessions.Sessions 
```

![vol5](https://i.imgur.com/YcTjn7U.png)

#### 6. Ficheros transferidos recientemente por NetBios

#### 7. Contenido de la caché DNS

#### 8. Variables de entorno

Para ver las variables de entorno, uso el comando `envars`:

```bash
python vol.py -f "/media/roberto/usb/memdump.mem"  windows.envars.Envars
```

![vol6](https://i.imgur.com/IUSyeJ2.png)

### Volcado del registro

Para realizar el volcado de registro he usado también la herramienta **FTK Imager**. Utilizo la opción `Obtain system files`:

![ftk5](https://i.imgur.com/JUcvnmy.png)

Una vez finalizado el volcado, utilizo el programa **Registry Viewer** para analizar los datos obtenidos.

#### 10. Redes wifi utilizadas recientemente

Para ver las redes wifi usadas recientemente, abro el archivo `software`, y ahí sigo la siguiente ruta: `Microsoft/Windows NT/CurrentVersion/NetworkList/Profiles`:

![reg1](https://i.imgur.com/RFzUv61.png)

#### 11. Configuración del firewall de nodo

Para ver la configuración del firewall de nodo, abro el archivo `system`, y ahí sigo la siguiente ruta: `ControlSet001/Services/SharedAccess/Parameters/FirewallPolicy/FirewallRules`:

![reg2](https://i.imgur.com/4b7ZsO1.png)

#### 12. Programas que se ejecutan en el Inicio

Para ver los programas que se ejecutan en el inicio, abro el archivo `software`, y ahí sigo la siguiente ruta: `Microsoft/Windows/CurrentVersion/Run`:

![reg3](https://i.imgur.com/6MsrP73.png)

#### 13. Asociación de extensiones de ficheros y aplicaciones

No he podido encontrar en la aplicación **Registry Viewer** los registros, pero usando regedit en la máquina, se encuentran en la siguiente localización: `Computer\HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts`:

![reg4](https://i.imgur.com/Ig5FCUk.png)


### Volcado de disco

Para realizar el volcado de disco he usado la herramienta FTK Imager también:

![ftk1](https://i.imgur.com/tUwr02N.png)

Selecciono **RAW** como tipo de imagen:

![ftk2](https://i.imgur.com/GWoxYEU.png)

Y, como indica la ayuda, en Fragment size pongo 0, además de indicar la ruta y el nombre del fichero:

![ftk3](https://i.imgur.com/cTgXwqp.png)

El resto de los pasos del proceso los dejo con los valores por defecto.

Ahora, para analizar los datos, utilizo Autopsy; para ello, abro el fichero que he creado con FTK Imager, indicamos el direcorio del fichero , y en tipo, selecciono **Disk image or VM file**:

![autopsy1](https://i.imgur.com/JHCRjQ2.png)

Tras finalizar la configuración, empezará a analizar el volcado de disco. Este proceso tarda bastante tiempo en completarse. Una vez acabado podemos analizar los datos obtenidos.

#### 9. Dispositivos USB conectados

Para ver los dispositivos USB conectados, utilizo la opción `USB Device Attached`:

![autopsy8](https://i.imgur.com/1XfoSfH.png)

#### 14. Aplicaciones usadas recientemente

Para ver las aplicaciones usadas recientemente, utilizo la opción `User Activity` del disco duro:

![autopsy9](https://i.imgur.com/vthHo40.png)

#### 15. Ficheros abiertos recientemente

![autopsy9](https://i.imgur.com/ZQtfblE.png)

#### 16. Software Instalado

Para ver el software instalado, utilizo la opción `Installed Programs`:

![autopsy10](https://i.imgur.com/xsFb4yR.png)

#### 18. Cuentas de Usuario

Para ver las cuentas de usuario, utilizo la opción `OS Accounts`:

![autopsy11](https://i.imgur.com/A1Ha5e6.png)

#### 19. Historial de navegación y descargas, cookies

Para ver el historial de navegación, utilizo la opción `Web History`:

![autopsy12](https://i.imgur.com/1EN0RI4.png)

Para ver las cookies utilizo la opción `Web Cookies`:

![autopsy13](https://i.imgur.com/rDaxg3p.png)

Para ver el historial de descargas, utilizo la opción `Web Downloads`:

![autopsy14](https://i.imgur.com/A6x55kE.png)

#### 21.  Archivos con extensión cambiada

Los archivos con extensión cambiada aparecen en la sección `Analysis Results/Extension Mismatch Detected`:

![autopsy2](https://i.imgur.com/hmLGaGi.png)

#### 22.  Archivos eliminados

Los archivos eliminados aparecen en la sección `Recycle Bin`:

![autopsy3](https://i.imgur.com/XmQIyKC.png)

#### 23.  Archivos Ocultos

En la opción para explorar el sistema de archivos, se pueden distinguir los archivos ocultos porque en los metadatos, aparece la etiqueta: `Hidden`:

![autopsy4](https://i.imgur.com/OcIKUYP.png)

#### 24.  Archivos que contienen una cadena determinada

Para buscar archivos que contengan una cadena determinada, utilizo la opción `Keyword Search`:

![autopsy5](https://i.imgur.com/B9ezFRy.png)

#### 25.  Búsqueda de imágenes por ubicación

Para buscar imágenes por ubicación, utilizo la opción `Geolocation`:

![autopsy6](https://i.imgur.com/G9nTp6h.png)

#### 26.  Búsqueda de archivos por autor

Para buscar archivos por autor, utilizo la opción `Metadata`:

![autopsy7](https://i.imgur.com/XcQPTmy.png)

## Apartado B) Máquina Linux

Intenta realizar las mismas operaciones en una máquina Linux para aquellos apartados que tengan sentido y no se realicen de manera idéntica a Windows.

### Volcado de memoria

He realizado el volcado de memoria con **Lime**, que es una herramienta que se utiliza para realizar volcados de memoria en Linux. Para ello, he usado el comando de la siguiente manera  (he instalado Lime meadiante su repositorio en github):

```bash
insmod lime-4.19.0-23-amd64.ko "path=/mnt/linux/memorialinux.mem format=lime"
```

Es importante que para realizar el volcado, hay que iniciar el sistema de forma insegura, ya que si no, no permite utilizar el comando.

No he sido capaz de realizar el análisis utilizando volatility, ya que es necesario instalar plugins para interpretar el volcado de memoria, y no los reconoce, por lo que voy a usar los comandos en lugar de trabajar sobre el volcado.

#### 1. Procesos en ejecución

Para ver los procesos en ejecución, utilizo el comando `ps aux`:

![ps1](https://i.imgur.com/I6H5Egn.png)

#### 2. Servicios en ejecución

Para ver los servicios en ejecución, utilizo el comando `systemctl`:

```bash
systemctl list-units --type=service --state=running
```

![systemctl1](https://i.imgur.com/lh2yFCl.png)

#### 3. Puertos abiertos

Para ver los puertos abiertos, utilizo el comando `netstat`, que se encuentra en el paquete `net-tools`:

```bash
apt install net-tools
netstat -tulpn
```

![netstat1](https://i.imgur.com/QmwsCnY.png)

#### 4. Conexiones establecidas por la máquina

Las sesiones se pueden observar en el comando netstat utilizado anteriormente.

#### 5. Sesiones de usuario establecidas remotamente

Para ver las sesiones de usuario establecidas remotamente, utilizo el comando `who`:

```bash
who -a
```

![who1](https://i.imgur.com/m6c6R6z.png)

#### 7. Contenido de la caché DNS

En debian, la caché dns está deshabilitada por defecto. Para habilitarla, voy a instalar el paquete **nscd** (demonio de caché para servicio de nombres), y leer el fichero que genera. El fichero tiene un formato binario, por lo que voy a usar el comando `strings` para ver su contenido:

```bash
strings /var/cache/nscd/hosts
```

![nscd1](https://i.imgur.com/4rfJMeG.png)

#### 8. Variables de entorno

Para ver las variables de entorno, utilizo el comando `env`:

![env1](https://i.imgur.com/O4fIJRT.png)

### Volcado de disco

El volcado de disco en linux lo he realizado con el comando dd, que se utiliza para copiar archivos y volúmenes. Para ello, he usado el comando de la siguiente manera:

```bash
dd if=/dev/vda2 of=/mnt/linux/volcado_linux.001 bs=64K
```

![dd1](https://i.imgur.com/6P6cdSJ.png)

Es imporate que, durante el análisis de la imagen en Autopsy, el tiempo es mucho mayor, y que es de hecho la última fase, cuando ya se encuentra al 100% la que toma más tiempo.

Los apartados rellativos al análisis usando autopsy, o se realizan exactamente igual que en Windows, o no tienen sentido en Linux, por lo que no los están documentados aquí.