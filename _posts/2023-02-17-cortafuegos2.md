---
title: "Cortafuegos II: Perimetral con nftables"
date: 2023-02-17T11:58:43+01:00
draft: false
media_subpath: /assets/2023-02-17-cortafuegos2
image:
  path: featured.png
categories:
    - documentación
    - Seguridad y Alta Disponibilidad
tags:
    - Cortafuegos
    - nftables
---

## Enunciado

Realiza con nftables el ejercicio de la página [https://fp.josedomingo.org/seguridadgs/u03/perimetral_iptables.html](https://fp.josedomingo.org/seguridadgs/u03/perimetral_iptables.html) documentando las pruebas de funcionamiento realizadas.

Debes añadir después las reglas necesarias para que se permitan las siguientes operaciones:



## Preparación

El escenario es el siguiente

![escenario](https://i.imgur.com/ynMPcoB.png)

Instalo nftables en el cortafuegos

```bash
sudo apt update
sudo apt install nftables
```

Creo las tablas de filter y nat

```bash
sudo nft add table inet filter
sudo nft add table inet nat
```

creo las cadenas de filter

```bash
sudo nft add chain inet filter input { type filter hook input priority 0 \; counter \; policy accept \; }
sudo nft add chain inet filter output { type filter hook output priority 0 \; counter \; policy accept \; }
sudo nft add chain inet filter forward { type filter hook forward priority 0 \; counter \; policy accept \; }
```

creo las cadenas de nat

```bash
sudo nft add chain inet nat prerouting { type nat hook prerouting priority 0 \; }
sudo nft add chain inet nat postrouting { type nat hook postrouting priority 100 \; }
```

### SSH al cortafuegos

Ahora acepto el tráfico ssh entrante al router-fw

```bash
sudo nft add rule inet filter input ip saddr 172.22.0.0/16 tcp dport 22 ct state new,established counter accept
sudo nft add rule inet filter output ip daddr 172.22.0.0/16 tcp sport 22 ct state established counter accept
```

y entrante desde la VPN

```bash
sudo nft add rule inet filter input ip saddr 172.29.0.0/16 tcp dport 22 ct state new,established counter accept
sudo nft add rule inet filter output ip daddr 172.29.0.0/16 tcp sport 22 ct state established counter accept
```

### Política por defecto

Y pongo la política por defecto a drop:

```bash
sudo nft chain inet filter input { policy drop \; }
sudo nft chain inet filter output { policy drop \; }
```

Ahora compruebo que puedo hacer ssh

![ssh](https://i.imgur.com/T2NL5kC.png)

![ssh2](https://i.imgur.com/7o6qhGY.png)

### Activar el bit de forward

En el cortafuegos, activo el bit de forwarding

![bitforward](https://i.imgur.com/Ooq3yo9.png)

### SNAT

```bash
sudo nft add rule inet nat postrouting oifname "ens3" ip saddr 192.168.100.0/24 counter masquerade
```

![snat](https://i.imgur.com/bWXZJ8j.png)

### SSH desde el cortafuego a la LAN

```bash
sudo nft add rule inet filter output oifname "ens4" ip daddr 192.168.100.0/24 tcp dport 22 ct state new,established counter accept
sudo nft add rule inet filter input iifname "ens4" ip saddr 192.168.100.0/24 tcp sport 22 ct state established counter accept
```

![ssh3](https://i.imgur.com/WRuODxe.png)

### Tráfico para la interfaz loopback

```bash
sudo nft add rule inet filter output oifname "lo" counter accept
sudo nft add rule inet filter input iifname "lo" counter accept
```

![loopback](https://i.imgur.com/fEVtFCW.png)

### Peticiones y respuestas protocolo ICMP

Desde el cortafuegos a internet

```bash
sudo nft add rule inet filter input iifname "ens3" icmp type echo-request counter accept
sudo nft add rule inet filter output oifname "ens3" icmp type echo-reply counter accept
```

Ahora desde mi portátil hago un ping al cortafuegos:

![icmp](https://i.imgur.com/vO8QNUq.png)

### Reglas forward

#### ping desde la LAN

Desde el cortafuegos a la LAN

```bash
sudo nft add rule inet filter input iifname "ens4" icmp type echo-reply counter accept
sudo nft add rule inet filter output oifname "ens4" icmp type echo-request counter accept
```

![icmp](https://i.imgur.com/oeg8xx6.png)

#### Consultas y respuestas DNS desde la LAN

```bash
sudo nft add rule inet filter forward iifname "ens4" oifname "ens3" ip saddr 192.168.100.0/24 udp dport 53 ct state new,established counter accept
sudo nft add rule inet filter forward iifname "ens3" oifname "ens4" ip daddr 192.168.100.0/24 udp sport 53 ct state established counter accept
```

![dns](https://i.imgur.com/vnJEfIP.png)

#### Permitimos la navegación web desde la LAN

```bash
sudo nft add rule inet filter output oifname "ens3" ip protocol tcp tcp dport { 80,443 } ct state new,established counter accept
sudo nft add rule inet filter input iifname "ens3" ip protocol tcp tcp sport { 80,443 } ct state established counter accept
```

![web](https://i.imgur.com/s4Yw8Cl.png)

#### Permitimos el acceso a nuestro servidor web de la LAN desde el exterior

```bash
sudo nft add rule inet filter forward iifname "ens3" oifname "ens4" ip daddr 192.168.100.0/24 tcp dport 80 ct state new,established counter accept
sudo nft add rule inet filter forward iifname "ens4" oifname "ens3" ip saddr 192.168.100.0/24 tcp sport 80 ct state established counter accept
```

```bash
sudo nft add rule inet nat prerouting iifname "ens3" tcp dport 80 counter dnat ip to 192.168.100.10
```

![web2](https://i.imgur.com/C69ZdJ8.png)


## Reglas del enunciado

### Permite poder hacer conexiones ssh al exterior desde la máquina cortafuegos

```bash
sudo nft add rule inet filter output oifname "ens3" tcp dport 22 ct state new,established counter accept
sudo nft add rule inet filter input iifname "ens3" tcp sport 22 ct state established counter accept
```

Ahora pruebo accediendo a otra máquina desde el cortafuegos por ssh

![ssh](https://i.imgur.com/YsoD8Cx.png)

### Permite hacer consultas DNS desde la máquina cortafuegos sólo al servidor 192.168.202.2. Comprueba que no puedes hacer un dig @1.1.1.1.

Creo la regla

```bash
sudo nft add rule inet filter output ip daddr 192.168.202.2 udp dport 53 ct state new,established counter accept
sudo nft add rule inet filter input ip saddr 192.168.202.2 udp sport 53 ct state established counter accept
```

Compruebo que no puedo hacer un dig @1.1.1.1 y si uno con @192.168.202.2

![dns](https://i.imgur.com/XKHU64n.png)

### Permite que la máquina cortafuegos pueda navegar por internet.

```bash
sudo nft add rule inet filter output oifname "ens3" ip protocol tcp tcp dport { 80,443 } ct state new,established counter accept
sudo nft add rule inet filter input iifname "ens3" ip protocol tcp tcp sport { 80,443 } ct state established counter accept
```

Compruebo que puedo navegar por internet

![web](https://i.imgur.com/dXNkvJz.png)

### Los equipos de la red local deben poder tener conexión al exterior.

Este paso lo realicé en la preparación en el siguiente apartado: [Reglas forward](#reglas-forward)

### Permitimos el ssh desde el cortafuego a la LAN

Este paso lo realicé en la preparación en el siguiente apartado: [SSH desde el cortafuego a la LAN](#ssh-desde-el-cortafuego-a-la-lan)

Pruebo que funciona (usando mi clave privada)

![ssh2](https://i.imgur.com/JdG9dTH.png)

### Permitimos hacer ping desde la LAN a la máquina cortafuegos

```bash
sudo nft add rule inet filter input iifname "ens4" icmp type echo-request counter accept
sudo nft add rule inet filter output oifname "ens4" icmp type echo-reply counter accept
```

Compruebo que funciona

![icmp](https://i.imgur.com/reyRJ34.png)

### Permite realizar conexiones ssh desde los equipos de la LAN

```bash
sudo nft add rule inet filter forward iifname "ens4" oifname "ens3" ip saddr 192.168.100.0/24 tcp dport 22 ct state new,established counter accept
sudo nft add rule inet filter forward iifname "ens3" oifname "ens4" ip daddr 192.168.100.0/24 tcp sport 22 ct state established counter accept
```

Ahora, tras copiar mi clave privada a la máquina LAN, accedo a alfa por ssh

![ssh3](https://i.imgur.com/eZ9IVZf.png)

### Instala un servidor de correos en la máquina de la LAN. Permite el acceso desde el exterior y desde el cortafuego al servidor de correos. Para probarlo puedes ejecutar un telnet al puerto 25 tcp

### Permite poder hacer conexiones ssh desde exterior a la LAN

```bash
sudo nft add rule inet filter forward iifname "ens3" oifname "ens4" ip daddr 192.168.100.0/24 tcp dport 22 ct state new,established counter accept
sudo nft add rule inet filter forward iifname "ens4" oifname "ens3" ip saddr 192.168.100.0/24 tcp sport 22 ct state established counter accept
sudo nft add rule inet nat prerouting iifname "ens3" tcp dport 22 counter dnat ip to 192.168.100.10
```

Compruebo que al acceder a la IP del firewall entro en la maquina LAN

![ssh4](https://i.imgur.com/VzI01Oo.png)

### Modifica la regla anterior, para que al acceder desde el exterior por ssh tengamos que conectar al puerto 2222, aunque el servidor ssh este configurado para acceder por el puerto 22

```bash
sudo nft add rule inet nat prerouting iifname "ens3" tcp dport 2222 counter dnat ip to 192.168.100.10:22
```

Ahora entro usando el puerto 2222

![ssh5](https://i.imgur.com/Mm45WLy.png)

### Permite hacer consultas DNS desde la LAN sólo al servidor 192.168.202.2. Comprueba que no puedes hacer un dig @1.1.1.1

Como ya tengo una regla para las consultas dns desde la lan,busco los handles que tiene para borrarla

```bash
sudo nft -a list ruleset 
```

![dns2](https://i.imgur.com/IH9k9GK.png)

son el 22 y el 23. Ahora los borro:

```bash
sudo nft delete rule inet filter forward handle 22
sudo nft delete rule inet filter forward handle 23
```

Ahora añado las reglas para la LAN

```bash
sudo nft add rule inet filter forward iifname "ens4" oifname "ens3" ip saddr 192.168.100.0/24 ip daddr 192.168.202.2 udp dport 53 ct state new,established counter accept
sudo nft add rule inet filter forward iifname "ens3" oifname "ens4" ip saddr 192.168.202.2 ip daddr 192.168.100.0/24 udp sport 53 ct state established counter accept
```

![dns3](https://i.imgur.com/1zmmeCt.png)

### Permite que los equipos de la LAN puedan navegar por internet.

Este paso lo realicé en la preparación en el siguiente apartado: [Permite que los equipos de la LAN puedan navegar por internet.](#permite-que-los-equipos-de-la-lan-puedan-navegar-por-internet)

Compruebo que funciona 

![web2](https://i.imgur.com/wyT7DEF.png )