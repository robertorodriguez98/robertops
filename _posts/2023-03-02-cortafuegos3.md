---
title: "Cortafuegos III: perimetral sobre escenario"
date: 2023-03-02T23:19:45+01:00
media_subpath: /assets/2023-03-02-cortafuegos3
image:
  path: cover.png
categories:
    - documentación
    - Seguridad y Alta Disponibilidad
tags:
    - Cortafuegos
    - iptables
---

El escenario es el siguiente

![Escenario](https://i.imgur.com/LLToqTl.png)

Y las interfaces de alfa son las siguientes:

- ens3: Salida a internet
- ens8: DMZ
- br-intra: LAN

## Enunciado

Sobre el escenario creado en el módulo de servicios con las máquinas Alfa (Router), Bravo (DMZ), Charlie y Delta (LAN) y empleando iptables o nftables, configura un cortafuegos perimetral en la máquina Alfa de forma que el escenario siga funcionando completamente teniendo en cuenta los siguientes puntos:

##  Política por defecto DROP para las cadenas INPUT, FORWARD y OUTPUT.

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

Y permito el acceso al resto de máquinas

```bash
iptables -A OUTPUT -d 192.168.0.0/24 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -s 192.168.0.0/24 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

iptables -A OUTPUT -d 172.16.0.0/16 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A INPUT -s 172.16.0.0/16 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
```

(Este paso lo ejecuto después de crear las reglas ssh)

```bash
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
```

## El cortafuego debe cumplir al menos estas reglas:

### La máquina Alfa tiene un servidor ssh escuchando por el puerto 22, pero al acceder desde el exterior habrá que conectar al puerto 2222.


### Desde Delta y Bravo se debe permitir la conexión ssh por el puerto 22 a la máquina Alfa

de alfa a charlie/delta

```bash
sudo iptables -A OUTPUT -o br-intra -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -i br-intra -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
```

Prueba antes y después de crear la regla

![Escenario](https://i.imgur.com/oiiVuK8.png)

de alfa a bravo

```bash
sudo iptables -A OUTPUT -o ens8 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -i ens8 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
```

![Escenario](https://i.imgur.com/2rAyLZy.png)

### La máquina Alfa debe tener permitido el tráfico para la interfaz loopback

```bash
iptables -A INPUT -i lo -p icmp -j ACCEPT
iptables -A OUTPUT -o lo -p icmp -j ACCEPT
```

Pruebo que funciona, antes y después de aplicar la regla:

![loopback](https://i.imgur.com/7RfdzSj.png)

### A la máquina Alfa se le puede hacer ping desde la DMZ, pero desde la LAN se le debe rechazar la conexión (REJECT) y desde el exterior se rechazará de manera silenciosa.

```bash
iptables -A INPUT -s 172.16.0.200/16 -p icmp -m icmp --icmp-type echo-request -j ACCEPT
iptables -A OUTPUT -d 172.16.0.200/16 -p icmp -m icmp --icmp-type echo-reply -j ACCEPT
```

Ahora el reject a la LAN

```bash
iptables -A INPUT -s 192.168.1.0/24 -p icmp -m icmp --icmp-type echo-request -j REJECT
iptables -A OUTPUT -d 192.168.1.0/24 -p icmp -m icmp --icmp-type echo-reply -j REJECT
```

ping desde bravo:

![ping desde bravo](https://i.imgur.com/utA5CGz.png)

ping desde charlie:

![ping desde charlie](https://i.imgur.com/g6Z7xSD.png)

### La máquina Alfa puede hacer ping a la LAN, la DMZ y al exterior.

```bash
iptables -A OUTPUT -p icmp -m icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -p icmp -m icmp --icmp-type echo-reply -j ACCEPT
```

A la LAN:

![ping a la LAN](https://i.imgur.com/PrsN5x0.png)

A la DMZ:

![ping a la DMZ](https://i.imgur.com/PealPbe.png)

Al exterior:

![ping al exterior](https://i.imgur.com/e5iIex8.png)

### Desde la máquina Bravo se puede hacer ping y conexión ssh a las máquinas de la LAN.

```bash
iptables -A FORWARD -s 172.16.0.200/32 -d 192.168.0.0/24 -p icmp -m icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -d 172.16.0.200/32 -s 192.168.0.0/24 -p icmp -m icmp --icmp-type echo-reply -j ACCEPT

iptables -A FORWARD -s 172.16.0.200/32 -d 192.168.0.0/24 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -d 172.16.0.200/32 -s 192.168.0.0/24 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
```

Prueba de ping desde bravo a charlie:

![ping desde bravo a charlie](https://i.imgur.com/qLycsbI.png)

Prueba de ssh desde bravo a charlie:

![ssh desde bravo a charlie](https://i.imgur.com/XZF4qGQ.png)

### Desde cualquier máquina de la LAN se puede conectar por ssh a la máquina Bravo.

```bash
iptables -A FORWARD -s 192.168.0.0/24 -d 172.16.0.200/32 -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -s 172.16.0.200/32 -d 192.168.0.0/24 -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT
```

Pruebo a acceder desde charlie:

![ssh desde charlie a bravo](https://i.imgur.com/2rykuVx.png)

### Configura la máquina Alfa para que las máquinas de LAN y DMZ puedan acceder al exterior

DMZ a exterior:

```bash
iptables -t nat -A POSTROUTING -s 172.16.0.0/16 -o ens3 -j MASQUERADE
iptables -A FORWARD -i ens8 -o ens3 -p icmp -m icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -i ens3 -o ens8 -p icmp -m icmp --icmp-type echo-reply -j ACCEPT
```

LAN a exterior:

```bash
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o ens3 -j MASQUERADE
iptables -A FORWARD -i br-intra -o ens3 -p icmp -m icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -i ens3 -o br-intra -p icmp -m icmp --icmp-type echo-reply -j ACCEPT
```

Prueba de ping desde bravo a google:

![ping desde bravo a google](https://i.imgur.com/IbX1h7r.png)

Prueba de ping desde charlie a google:

![ping desde charlie a google](https://i.imgur.com/g7GKV9E.png)

### Las máquinas de la LAN pueden hacer ping al exterior y navegar

El ping lo he configurado en el punto anterior. Ahora la navegación:

```bash
iptables -A FORWARD -i br-intra -o ens3 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens3 -o br-intra -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT

iptables -A FORWARD -i br-intra -o ens3 -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens3 -o br-intra -p tcp --sport 443 -m state --state ESTABLISHED -j ACCEPT
```

Prueba de navegación desde charlie (no tengo el comando curl, asi que uso nc):

![navegación desde charlie](https://i.imgur.com/ZLljVQQ.png)

### La máquina Bravo puede navegar

```bash
iptables -A FORWARD -i ens8 -o ens3 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens3 -o ens8 -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT

iptables -A FORWARD -i ens8 -o ens3 -p tcp --dport 443 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens3 -o ens8 -p tcp --sport 443 -m state --state ESTABLISHED -j ACCEPT
```

Prueba de navegación desde bravo:

![navegación desde bravo](https://i.imgur.com/qXEvqkP.png)

### Configura la máquina Alfa para que los servicios web y ftp sean accesibles desde el exterior

```bash
iptables -t nat -A PREROUTING -p tcp -i ens3 --dport 80 -j DNAT --to 172.16.0.200
iptables -A FORWARD -i ens3 -o ens8 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens8 -o ens3 -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT

iptables -t nat -A PREROUTING -p tcp -i ens3 --dport 21 -j DNAT --to 172.16.0.200
iptables -A FORWARD -i ens3 -o ens8 -p tcp --dport 21 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens8 -o ens3 -p tcp --sport 21 -m state --state ESTABLISHED -j ACCEPT
```

Prueba de navegación desde el exterior (La página es de un taller de Django):

![navegación desde el exterior](https://i.imgur.com/U2EgQqy.png)

### El servidor web y el servidor ftp deben ser accesibles desde la LAN y desde el exterior

```bash
iptables -A FORWARD -i br-intra -o ens8 -p tcp --dport 80 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens8 -o br-intra -p tcp --sport 80 -m state --state ESTABLISHED -j ACCEPT

iptables -A FORWARD -i br-intra -o ens8 -p tcp --dport 21 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens8 -o br-intra -p tcp --sport 21 -m state --state ESTABLISHED -j ACCEPT
```

Prueba de navegación desde charlie, sale un error porque estoy usando el comando nc, pero aun asi se ve que responde rocky con wsgi, que es lo que hay desplegado en bravo:

![navegación desde charlie](https://i.imgur.com/J9C1mcC.png)

### El servidor de correos sólo debe ser accesible desde la LAN

```bash
iptables -A FORWARD -i br-intra -o ens8 -p tcp --dport 25 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens8 -o br-intra -p tcp --sport 25 -m state --state ESTABLISHED -j ACCEPT
```

### En la máquina Charlie instala un servidor mysql si no lo tiene aún. A este servidor se puede acceder desde la DMZ, pero no desde el exterior.

### Evita ataques DoS por ICMP Flood, limitando el número de peticiones por segundo desde una misma IP.

El ping está bloqueado desde el exterior y desde la LAN, por lo que voy a evitar los ataques desde la DMZ, limitando a 1 peticion por segundo(primero hay que borrar la regla anterior):

```bash
iptables -A INPUT -i ens8 -p icmp -m state --state NEW --icmp-type echo-request -m limit --limit 1/s --limit-burst 1 -j ACCEPT
```

![ping desde la DMZ](https://i.imgur.com/L2N9GIc.png)

En la captura se ve como el 100% de los paquetes han sido rechazados

### Evita ataques DoS por SYN Flood.

```bash
iptables -t raw -D PREROUTING -p tcp -m tcp --syn -j CT --notrack
iptables -D INPUT -p tcp -m tcp -m conntrack --ctstate INVALID,UNTRACKED -j SYNPROXY --sack-perm --timestamp --wscale 7 --mss 1460
iptables -D INPUT -m conntrack --ctstate INVALID -j DROP 
```

### Evita que realicen escaneos de puertos a Alfa.

```bash
iptables -N antiscan
iptables -A antiscan -j DROP
```

## Debemos implementar que el cortafuegos funcione después de un reinicio de la máquina.

Para hacer la instalación persistente, he utilizado el paquete iptables-persistent

```bash
apt install iptables-persistent
```

Para que funcione, tras crear todas las reglas, ejecuto el siguiente comando:

```bash
sudo iptables-save > /etc/iptables/rules.v4
```

Tras ejecutar eso, las reglas son persistentes. El fichero tiene el siguiente contenido:

![iptables-save](https://i.imgur.com/KbSN5IX.png)