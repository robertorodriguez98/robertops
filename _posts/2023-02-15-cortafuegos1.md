---
title: "Cortafuegos I: De nodo con iptables"
date: 2023-02-15T23:46:36+01:00
draft: false
media_subpath: /assets/2023-02-15-cortafuegos1
image:
  path: featured.png
categories:
    - documentación
    - Seguridad y Alta Disponibilidad
tags:
    - Cortafuegos
    - iptables
---

Enunciado: [https://fp.josedomingo.org/seguridadgs/u03/ejercicio1.html](https://fp.josedomingo.org/seguridadgs/u03/ejercicio1.html)

## Preparación

**Limpiamos las reglas previas**

```bash
iptables -F
iptables -t nat -F
iptables -Z
iptables -t nat -Z
```

**Acceso por SSH**

Antes de añadir la política por defecto voy a añadir reglas para permitir el acceso por ssh

```bash
iptables -A INPUT -s 172.22.0.0/16 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -d 172.22.0.0/16 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
```

Estas reglas sirve para acceder desde la misma red, además añado las siguientes para acceder a través de la VPN

```bash
iptables -A INPUT -s 172.29.0.0/16 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -d 172.29.0.0/16 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
```

Ahora añado las **políticas por defecto**

```bash
iptables -P INPUT DROP
iptables -P OUTPUT DROP
```

Ahora pruebo que se han aplicado, por ejemplo, haciendo un ping:

![ping](https://i.imgur.com/GgWurZe.png)

**Permitimos tráfico por la interfaz de loopback**

```bash
iptables -A INPUT -i lo -p icmp -j ACCEPT
iptables -A OUTPUT -o lo -p icmp -j ACCEPT
```

**Peticiones y respuestas del protocolo ICMP**

```bash
iptables -A INPUT -i ens3 -p icmp --icmp-type echo-reply -j ACCEPT
iptables -A OUTPUT -o ens3 -p icmp --icmp-type echo-request -j ACCEPT
```

Pruebo que funciona haciendo un ping

![ping2](https://i.imgur.com/eTTjjEV.png)

**Consultas y respuestas DNS**

```bash
iptables -A OUTPUT -o ens3 -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i ens3 -p udp --sport 53 -m state --state ESTABLISHED -j ACCEPT
```

Pruebo que funciona haciendo una consulta DNS

![dns](https://i.imgur.com/Ep1vuVz.png)

**Tráfico HTTP**

```bash
iptables -A OUTPUT -o ens3 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i ens3 -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT
```

Pruebo que funciona haciendo una consulta HTTP

![http](https://i.imgur.com/aB17haB.png)

**Tráfico HTTPS**

```bash
iptables -A OUTPUT -o ens3 -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i ens3 -p tcp --sport 443 -m state --state ESTABLISHED -j ACCEPT
```

Pruebo que funciona haciendo una consulta HTTPS

![https](https://i.imgur.com/BzyJeje.png)

**Tráfico HTTP/HTTPs**

Los dos puntos anteriores se pueden resumir en una sola regla

```bash
iptables -A OUTPUT -o ens3 -p tcp -m multiport --dports 80,443 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -i ens3 -p tcp -m multiport --sports 80,443 -m state --state ESTABLISHED -j ACCEPT
```

**Acceso al servidor web**

```bash
iptables -A INPUT -i ens3 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o ens3 -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT
```

Pruebo que funciona haciendo una consulta HTTP desde el exterior

![web](https://i.imgur.com/1TbKhY2.png)

## Ejercicios

### 1. Permite poder hacer conexiones ssh al exterior

Para esto uso las reglas de ssh citas anteriormente:

```bash
iptables -A INPUT -s 172.22.0.0/16 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -d 172.22.0.0/16 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
```

Estas reglas sirve para acceder desde la misma red, además añado las siguientes para acceder a través de la VPN

```bash
iptables -A INPUT -s 172.29.0.0/16 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -d 172.29.0.0/16 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
```

![ssh1](https://i.imgur.com/8h6tmFh.png)
![ssh2](https://i.imgur.com/xhNYful.png)

### 2. Deniega el acceso a tu servidor web desde una ip concreta

Como ya he creado en la preparación una regla que permite el acceso al servidor web, para que el bloque funcione tengo que añadir la regla antes, ya que el orden es importante en iptables. Para ello, primero miro la posición de la regla que permite el acceso al servidor web

```bash
iptables -L -n -v --line-numbers
```

![iptables](https://i.imgur.com/VLs4Xd7.png)

La regla que permite el acceso está en la dirección 8; ahora creo la regla con la ip de mi máqunina:

```bash
iptables -I INPUT 8 -s 172.29.0.42 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j DROP
```

![iptables2](https://i.imgur.com/T361Yz0.png)

Ahora compruebo que no puedo acceder al servidor web desde mi máquina

![web](https://i.imgur.com/9xydTG9.png)

### 3. Permite hacer consultas DNS sólo al servidor 192.168.202.2. Comprueba que no puedes hacer un dig @1.1.1.1

Primero borro las reglas de DNS que he creado anteriormente

```bash
iptables -D OUTPUT -o ens3 -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -D INPUT -i ens3 -p udp --sport 53 -m state --state ESTABLISHED -j ACCEPT
```

Y ahora añado las reglas nuevas, permitiendo solo el servidor 192.168.202.2:

```bash
iptables -A OUTPUT -d 192.168.202.2 -p udp --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -s 192.168.202.2 -p udp --sport 53 -m state --state ESTABLISHED -j ACCEPT
```

Ahora compruebo que no puedo hacer un `dig@1.1.1.1 www.josedomingo.org`:

![dns](https://i.imgur.com/May5Dwa.png)

Y si que puedo usando el dns, `dig@192.168.202.2 www.josedomingo.org`:

![dns2](https://i.imgur.com/1O9FXoM.png)

### 4. No permitir el acceso al servidor web de www.josedomingo.org, Tienes que utilizar la ip. ¿Puedes acceder a fp.josedomingo.org?

Al igual que en el ejercicio 2, primero miro la posición de la regla que permite el acceso al servidor web

![iptables](https://i.imgur.com/HbcTZPw.png)

Está en el lugar 5. Ahora creo la regla con la ip de josedomingo.org:

```bash
iptables -I OUTPUT 5 -d 37.187.119.60 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j DROP
```

Compruebo que se ha creado correctamente:

![iptables2](https://i.imgur.com/Xp4mGZu.png)

Ahora compruebo que no puedo acceder al servidor web de josedomingo.org

![web](https://i.imgur.com/POagTDZ.png)

y si que puedo acceder a portquiz.net:

![web2](https://i.imgur.com/f0SccEm.png)

### 5. Permite mandar un correo usando nuestro servidor de correo: babuino-smtp. Para probarlo ejecuta un telnet babuino-smtp.gonzalonazareno.org 25

Para hacerlo utilizo la ip de babuino:

```bash
iptables -A OUTPUT -d 192.168.203.3 -p tcp --dport 25 -j ACCEPT
iptables -A INPUT -s 192.168.203.3 -p tcp --sport 25 -j ACCEPT
```

![smtp](https://i.imgur.com/tBoRNWu.png)

### 6. Instala un servidor mariadb, y permite los accesos desde la ip de tu cliente. Comprueba que desde otro cliente no se puede acceder

Instalo MariaDB:

```bash
apt install mariadb-server
```

Configuro el acceso remoto, editando el fichero `/etc/mysql/mariadb.conf.d/50-server.cnf`:

```bash
bind-address            = 0.0.0.0
```

Tras eso, reinicio el servicio y añado la regla para permitir el acceso desde mi cliente:

```bash
sudo iptables -A INPUT -s 172.29.0.42 -p tcp --dport 3306 -j ACCEPT
sudo iptables -A OUTPUT -d 172.29.0.42 -p tcp --sport 3306 -j ACCEPT
```

Ahora, en la siguiente captura, realizo una conexión con la base de datos desde el cliente, tras eso, desconecto la VPN para dejar de tener la IP que está autorizada, y vuelvo a intentar acceder, pero no puedo:

![mariadb](https://i.imgur.com/1Z8hCqe.png)
