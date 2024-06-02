---
title: "Redes Privadas Virtuales con WireGuard"
date: 2023-01-26T22:01:09+01:00
draft: false
media_subpath: /assets/2023-01-26-vpn_wireguard
image:
  path: featured.png
categories:
    - documentación
    - Seguridad y Alta Disponibilidad
tags:
    - VPN
    - wireguard
---

## Caso C: VPN de acceso remoto con WireGuard


Monta una VPN de acceso remoto usando Wireguard. Intenta probarla con clientes Windows, Linux y Android. Documenta el proceso adecuadamente y compáralo con el del apartado A.


El Escenario es el siguiente:

![escenario1](https://i.imgur.com/vob221j.png)

Vamos a utilizar un VagrantFile igual al utilizado en el caso A para montar la infraestructura necesaria para la práctica:

```ruby
Vagrant.configure("2") do |config|

config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.define :cliente3 do |cliente3|
    cliente3.vm.box = "debian/bullseye64"
    cliente3.vm.hostname = "cliente3"
    cliente3.vm.network :private_network,
      :libvirt__network_name => "red-externa3",
      :libvirt__dhcp_enabled => false,
      :ip => "192.168.0.20",
      :libvirt__netmask => '255.255.255.0',
      :libvirt__forward_mode => "veryisolated"
  end

  config.vm.define :servidor3 do |servidor3|
    servidor3.vm.box = "debian/bullseye64"
    servidor3.vm.hostname = "servidor3"
    servidor3.vm.network :private_network,
      :libvirt__network_name => "red-externa3",
      :libvirt__dhcp_enabled => false,
      :ip => "192.168.0.10",
      :libvirt__netmask => '255.255.255.0',
      :libvirt__forward_mode => "veryisolated"
    servidor3.vm.network :private_network,
      :libvirt__network_name => "red-interna3",
      :libvirt__dhcp_enabled => false,
      :ip => "192.168.1.10",
      :libvirt__netmask => '255.255.255.0',
      :libvirt__forward_mode => "veryisolated"
  end

  config.vm.define :maquina3 do |maquina3|
    maquina3.vm.box = "debian/bullseye64"
    maquina3.vm.hostname = "maquina3"
    maquina3.vm.network :private_network,
      :libvirt__network_name => "red-interna3",
      :libvirt__dhcp_enabled => false,
      :ip => "192.168.1.30",
      :libvirt__netmask => '255.255.255.0',
      :libvirt__forward_mode => "veryisolated"
  end
end
```

Ahora vamos a configurar las máquinas:

### Servidor

Instalamos wireguard:

```bash
sudo apt update
sudo apt install wireguard
```

Activamos el bit de forwarding en el servidor editando el fichero `/etc/sysctl.conf` y descomentando la siguiente línea:

```bash
net.ipv4.ip_forward=1
```

y hacemos los cambios efectivos:

```bash
sudo sysctl -p
```

Ahora vamos a generar los pares de claves para el servidor (como usuario root):

```bash
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey | tee /etc/wireguard/server_public.key
```

Ahora vamos a crear el fichero de configuración del servidor en `/etc/wireguard/wg0.conf`,  utilizando las claves que hemos generado en el paso anterior:

```bash
[Interface]
Address = 10.99.99.1/24
ListenPort = 51820
PrivateKey = aB9gyJdOH835WVK4bqbb2VqrGeW5wFuOIyHFx7suu1w=


```

Al tratarse de fichero sensibles, tienen que tener permisos de solo lectura, por lo que vamos a cambiar los permisos:

```bash
sudo chmod -R 600 /etc/wireguard/
```

Creamos la interfaz:

```bash
sudo wg-quick up /etc/wireguard/wg0.conf
```

![wgup](https://i.imgur.com/4avm7tC.png)

### Cliente

Instalamos wireguard:

```bash
sudo apt update
sudo apt install wireguard
```

Ahora vamos a generar los pares de claves para el cliente  (como usuario root):

```bash
wg genkey | tee /etc/wireguard/client_private.key | wg pubkey | tee /etc/wireguard/client_public.key
```

hora vamos a crear el fichero de configuración del cliente en `/etc/wireguard/wg0.conf`,  utilizando la clave privada generada en el paso anterior y la clave pública del servidor:

```bash
[Interface]
Address = 10.99.99.2/24
PrivateKey = 8DFSQc0qbT3P9Dhnbg44bxU+W2uRraXsebB+suQH+nQ=

[Peer]
PublicKey = voKHGdJUz8B6Q6jRYJspzhSWDLmXI4jroPc89VkMCHQ=
AllowedIPs = 0.0.0.0/0
Endpoint = 192.168.0.10:51820
PersistentKeepalive = 25
```
Al tratarse de fichero sensibles,  tienen que tener permisos de solo lectura, por lo que vamos a cambiar los permisos:

```bash
sudo chmod -R 600 /etc/wireguard/
```

Creamos la interfaz:

```bash
sudo wg-quick up /etc/wireguard/wg0.conf
```

![wgup2](https://i.imgur.com/hsQTSjy.png)

Una vez hecho esto, tenemos que añadir la clave pública del cliente al fichero de configuración del **servidor**, añadiendo las siguentes líneas:

```bash
[Peer]
PublicKey = eh7Ap8nkBQf5vL60sp2ORzqLtz2YWnbjABbTMrukaCo=
AllowedIPs = 10.99.99.2/32
```

y reiniciamos la interfaz:

```bash
sudo wg-quick down /etc/wireguard/wg0.conf
sudo wg-quick up /etc/wireguard/wg0.conf
```

Podemos ver el estado de la interfez con el comando `wg`:

![wg](https://i.imgur.com/GIJCLAo.png)

### Rutas

Para que los mensajes que se envíen desde la máquina cliente a la máquina servidor, pasen por el túnel VPN, tenemos que cambiar la ruta por defecto para que sea a través del servidor:

```bash
sudo ip route del default
sudo ip route add default via 10.99.99.1
```

Tenemos que cambiar la ruta por defecto también de la máquina interna para que sea a través del servidor:

```bash
sudo ip route del default
sudo ip route add default via 192.168.1.10
```

### Comprobación

Para comprobar que funciona, vamos a hacer un `traceroute` desde la máquina cliente a la máquina servidor:

![traceroute1](https://i.imgur.com/RxFLZJh.png)

## Caso D: VPN sitio a sitio con WireGuard

Configura una VPN sitio a sitio usando WireGuard. Documenta el proceso adecuadamente y compáralo con el del apartado B.

El Escenario es el siguiente:

![escenario2](https://i.imgur.com/VGD6hgl.png)

El escenario es similar al del caso B por lo que utilizaremos el mismo vagrantfile:

```ruby
Vagrant.configure("2") do |config|

config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.define :maquina1 do |maquina1|
    maquina1.vm.box = "debian/bullseye64"
    maquina1.vm.hostname = "maquina1"
    maquina1.vm.network :private_network,
      :libvirt__network_name => "interna1",
      :libvirt__dhcp_enabled => false,
      :ip => "192.168.0.20",
      :libvirt__netmask => '255.255.255.0',
      :libvirt__forward_mode => "veryisolated"
  end

  config.vm.define :cliente do |cliente|
    cliente.vm.box = "debian/bullseye64"
    cliente.vm.hostname = "cliente"
    cliente.vm.network :private_network,
      :libvirt__network_name => "interna1",
      :libvirt__dhcp_enabled => false,
      :ip => "192.168.0.10",
      :libvirt__netmask => '255.255.255.0',
      :libvirt__forward_mode => "veryisolated"
    cliente.vm.network :private_network,
      :libvirt__network_name => "internet",
      :libvirt__dhcp_enabled => false,
      :ip => "10.20.30.1",
      :libvirt__netmask => '255.255.255.0',
      :libvirt__forward_mode => "veryisolated"
  end

  config.vm.define :servidor do |servidor|
    servidor.vm.box = "debian/bullseye64"
    servidor.vm.hostname = "servidor"
    servidor.vm.network :private_network,
      :libvirt__network_name => "internet",
      :libvirt__dhcp_enabled => false,
      :ip => "10.20.30.2",
      :libvirt__netmask => '255.255.255.0',
      :libvirt__forward_mode => "veryisolated"
    servidor.vm.network :private_network,
      :libvirt__network_name => "interna2",
      :libvirt__dhcp_enabled => false,
      :ip => "172.22.0.10",
      :libvirt__netmask => '255.255.0.0',
      :libvirt__forward_mode => "veryisolated"
  end

  config.vm.define :maquina2 do |maquina2|
    maquina2.vm.box = "debian/bullseye64"
    maquina2.vm.hostname = "maquina2"
    maquina2.vm.network :private_network,
      :libvirt__network_name => "interna2",
      :libvirt__dhcp_enabled => false,
      :ip => "172.22.0.20",
      :libvirt__netmask => '255.255.0.0',
      :libvirt__forward_mode => "veryisolated"
  end
end
``` 

Ahora vamos a configurar las máquinas:

### Servidor

La configuración es similar a la del caso B, con la diferencia de que el fichero de configuración en `/etc/wireguard/wg0.conf` es el siguiente:

Las claves son:

* privada: `0N0kdHNHajtKY78rAGaI5uHzY8QGvZMCuiyw3WXU0n0=`
* pública: `SC7FuKTw2GnjJmJDmP0GuZGzgr9CBHUbcBOAXKKrCSU=`

```bash
[Interface]
Address = 10.99.99.1
ListenPort = 51820
PrivateKey = 0N0kdHNHajtKY78rAGaI5uHzY8QGvZMCuiyw3WXU0n0=
```

Creamos la interfaz con el siguiente comando:

```bash
sudo wg-quick up wg0
```

### Cliente

La configuración es similar a la del caso B, con la diferencia de que el fichero de configuración en `/etc/wireguard/wg0.conf` es el siguiente:

Las claves son:

* privada: `OLKDIsseCywbzWOwME1gxzIZLhopGljCeyYgibrHwm0=`
* pública: `jwqTMNZ4lQkVk2OLrlMGZGDCkkCLJFmcUjlF7aPvrWc=`

```bash
[Interface]
Address = 10.99.99.2
PrivateKey = OLKDIsseCywbzWOwME1gxzIZLhopGljCeyYgibrHwm0=
ListenPort = 51820

[Peer]
PublicKey = SC7FuKTw2GnjJmJDmP0GuZGzgr9CBHUbcBOAXKKrCSU=
AllowedIPs = 0.0.0.0/0
Endpoint = 10.20.30.2:51820
```

Creamos la interfaz con el siguiente comando:

```bash
sudo wg-quick up wg0
```

Activamos el bit de forwarding en el servidor editando el fichero `/etc/sysctl.conf` y descomentando la siguiente línea:

```bash
net.ipv4.ip_forward=1
```

y hacemos los cambios efectivos:

```bash
sudo sysctl -p
```

Ahora, como tenemos la clave pública del otro servidor, modificamos el fichero `/etc/wireguard/wg0.conf` del servidor para añadir la siguiente sección:

```bash
[Peer]
Publickey = jwqTMNZ4lQkVk2OLrlMGZGDCkkCLJFmcUjlF7aPvrWc=
AllowedIPs = 0.0.0.0/0
PersistentKeepAlive = 25
Endpoint = 10.20.30.1:51820
```

y reiniciamos el servicio:

```bash
sudo wg-quick down wg0
sudo wg-quick up wg0
```

### Máquinas

Ahora vamos a configurar las rutas en las maquinas internas:

Máquina1:

```bash
sudo ip route del default
sudo ip route add default via 192.168.0.10
```

Máquina2:

```bash
sudo ip route del default
sudo ip route add default via 172.22.0.10
```

### Prueba de funcionamiento

traceroute desde maquina1 a maquina2:

![traceroute2](https://i.imgur.com/0HeraM7.png)

traceroute desde maquina2 a maquina1:

![traceroute3](https://i.imgur.com/4WHGAH0.png)

## Conclusión

Utilizando WireGuard la configuración es más sencilla de realizar y tiene menos ficheros, por lo que es más fácil de gestionar y de depurar errores. Aparte de esto, el funcionamiento es el mismo que el de OpenVPN.