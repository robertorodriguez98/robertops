---
title: "Compilación Kernel"
date: 2022-12-07T21:18:17+01:00
draft: false
media_subpath: /assets/2022-12-07-compilacion-kernel
image:
  path: featured.png
categories:
    - documentación
    - Administración de Sistemas Operativos
tags:
    - compilación
    - Debian
---

## Compilación de un Kernel linux a medida

Al ser linux un kérnel libre, es posible descargar el código fuente, configurarlo y comprimirlo. Además, esta tarea a priori compleja, es más sencilla de lo que parece gracias a las herramientas disponibles.
En esta tarea debes tratar de compilar un kérnel completamente funcional que reconozca todo el hardware básico de tu equipo y que sea a la vez lo más pequeño posible, es decir que incluya un vmlinuz lo más pequeño posible y que incorpore sólo los módulos imprescindibles. Para ello utiliza el método explicado en clase y entrega finalmente el fichero deb con el kérnel compilado por ti.
El hardware básico incluye como mínimo el teclado, la interfaz de red y la consola gráfica (texto).

## Descarga

En este caso vamos a descargar el último kernel de linux de la [página oficial](https://kernel.org/):

```bash
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.0.7.tar.xz
tar xf linux-6.0.7.tar.xz
cd linux-6.0.7
```

## Compilación del kernel

Para configurar los módulos que tenemos cargados actualmente en el sistema tenemos que introducir losa siguientes comandos:

```bash
make oldconfig
make localyesconfig
```

Con lo siguiente podemos comprobar el número de módulos estáticos y dinámicos que tenemos actualmente:

```bash
egrep '=y' .config | wc -l
egrep '=m' .config | wc -l
```

Para compilar el kernel, tenemos que ejecutar el siguiente comando, que aprovecha el número de núcleos que tenemos para reducir al máximo el tiempo de compilación:

```bash
time make -j $(nproc) bindeb-pkg
```

## Reducir el kernel

Para reducir el tamaño del kernel tenemos que desactivar módulos. Éstos se desactivan ejecutando el siguiente comando:

```bash
make clean
make xconfig
```

que abre una interfaz gráfica en la que podemos seleccionar los módulos quq queremos activar o desactivar:

![https://i.imgur.com/cndWKk6.png](https://i.imgur.com/cndWKk6.png)

