---
title: "Ansible: Escenario router-nat"
date: 2022-10-18T13:49:56+02:00
draft: false
media_subpath: /assets/2022-10-18-ansible-router-nat
image:
  path: featured.png
categories:
    - documentación
    - Servicios de Red e Internet
tags:
    - Ansible
    - Vagrant
---

Creación del siguiente escenario con un cliente y un router-nat utilizando **vagrant** y **ansible**


![escenario](escenario.png)

## Vagrant

Según el esquema de red que tenemos que replicar, vamos a crear una **red muy aislada** entre las dos máquinas. También, el router tendrá un **bridge** que será su puerta de enlace predeterminada. En el caso del cliente, esta configuración se hará más adelante. El `Vagrantfile` queda de la siguiente manera:

```ruby
  config.vm.define :router do |router|
    router.vm.box = "debian/bullseye64"
    router.vm.hostname = "router"
    router.vm.synced_folder ".", "/vagrant", disabled: true
    router.vm.network :public_network,
      :dev => "br0",
      :mode => "bridge",
      :type => "bridge",
      use_dhcp_assigned_default_route: true
    router.vm.network :private_network,
      :libvirt__network_name => "red-muy-aislada",
      :libvirt__dhcp_enabled => false,
      :ip => "192.168.0.1",
      :libvirt__forward_mode => "veryisolated"
  end
  config.vm.define :cliente do |cliente|
    cliente.vm.box = "debian/bullseye64"
    cliente.vm.hostname = "cliente"
    cliente.vm.synced_folder ".", "/vagrant", disabled: true
    cliente.vm.network :private_network,
      :libvirt__network_name => "red-muy-aislada",
      :libvirt__dhcp_enabled => false,
      :ip => "192.168.0.2",
      :libvirt__forward_mode => "veryisolated"
  end
end
```

Creamos las máquinas virtuales:

```bash
vagrant up
```

## Ansible

Ahora nos movemos al directorio donde se va a encontrar el **playbook** (`ansible/`). empezamos por el fichero `hosts`;

### hosts

El fichero `hosts` contiene la información de las máquinas en las que vamos a realizar el despliegue, pero antes de crearlo necesitamos conseguir las direcciones IPs que tienen asignadas en la interfaz **eth0** (la de Vagrant). Para ello usamos el siguiente comando:

```bash
$ vagrant ssh cliente -c "hostname -I | cut -d' ' -f1" 2>/dev/null
192.168.121.77
```

```bash
$ vagrant ssh router -c "hostname -I | cut -d' ' -f1" 2>/dev/null 
==> router: You assigned a static IP ending in ".1" to this machine.
==> router: This is very often used by the router and can cause the
==> router: network to not work properly. If the network doesn't work
==> router: properly, try changing this IP.
192.168.121.146
```

Nos aparece una alerta ya que el router tiene una dirección IP acabada en ".1", Lo ignoramos ya que la máquina es el **router de la red**. Con la salida de ambos comandos tenemos las IPs de las máquinas y, añadiendo además las **rutas de las claves privadas**, podemos crear el fichero:

```yaml
all:
  children:
    maquinas:
      hosts:
        cliente:
          ansible_ssh_host: 192.168.121.77
          ansible_ssh_user: vagrant
          ansible_ssh_private_key_file: ../.vagrant/machines/cliente/libvirt/private_key
        router:
          ansible_ssh_host: 192.168.121.146
          ansible_ssh_user: vagrant
          ansible_ssh_private_key_file: ../.vagrant/machines/router/libvirt/private_key
```

Ahora podemos crear las máquinas con `vagrant up`:
![vagrant](vagrant.png)

### site.yaml

Tras eso creamos el fichero que contiene la información de asignación de roles, que deben ser de la siguiente manera:

* **common**: Estas tareas se deben ejecutar en todos los nodos: actualizar los paquetes y añadir tu clave pública a la máquinas para poder acceder a ellas con ssh. ¿Existe algún módulo de ansible que te permita copiar claves públicas?.
* **router**: Todas las tareas necesarias para configurar router cómo router-nat y que salga a internet por eth1. Las configuraciones deben ser permanentes. ¿Existe algún módulo de ansible que te permita ejecutar sysctl?.
* **cliente**: Todas las tareas necesarias para que las máquinas conectadas a la red privada salgan a internet por eth1.
* **web**: Las tareas necesarias para instalar y configurar un servidor web con una página estática en la máquina cliente.

```yaml
- hosts: all
  become: true
  roles:
   - role: common

- hosts: router
  become: true
  roles:
   - role: router

- hosts: cliente
  become: true
  roles:
   - role: web
   - role: cliente
```

### Roles

Para realizar el despliegue indicado tenemos que crear los roles. Las tareas de los roles, están contenidas en una estructura de carpetas dentro de la carpeta rol, siendo de la siguiente manera:

```bash
rolejemplo
├── defaults
├── files
├── handlers
├── library
├── tasks
├── templates
└── vars
```

conteniendo las tareas que realizará. Empezaremos por **common**:

#### Common

Este rol es bastante sencillo ya que solo cuenta con un fichero `tasks/main.yaml` que contiene la instrucción para comprobar que el sistema está actualizado:

```yaml
- name: Comprueba que el sistema esta actualizado
  apt: update_cache=yes upgrade=yes

- name: Introduce la clave publica desde un fichero
  authorized_key:
    user: vagrant
    state: present
    key: " { { lookup('file', '/home/roberto/.ssh/id_rsa.pub')  } }"
```

#### Router

Todas las tareas necesarias para configurar router cómo router-nat y que salga a internet por eth1. Las configuraciones deben ser permanentes. El contenido de `tasks/main.yaml` es el siguiente:

```yaml
- name: Cambia el bit de forward a 1
  ansible.posix.sysctl:
    name: net.ipv4.ip_forward
    value: '1'
    sysctl_set: yes
    state: present
    reload: yes

- name: Configuracion de DNAT
  iptables:
    chain: PREROUTING
    in_interface: eth1
    destination_port: 80
    jump: DNAT
    protocol: tcp
    table: nat
    to_destination: 10.0.0.2:80
  become: yes

- name: Configuracion de SNAT
  iptables:
    chain: POSTROUTING
    destination: 10.0.0.0/8
    jump: MASQUERADE
    out_interface: eth1
    table: nat
  become: yes
```

#### Web

Las tareas necesarias para instalar y configurar un servidor web con una página estática en la máquina cliente. El contenido de `tasks/main.yaml` es el siguiente:

```yaml
- name: "ensure apache2 is installed"
  apt:
    pkg: apache2
- name: copy template index
  template:
    src: index.j2
    dest: /var/www/html/index.html
    owner: www-data
    group: www-data
    mode: 0644

- name: "Copiar fichero al servidor remoto"
  copy:
    src: fichero.html
    dest: /var/www/html/fichero.html
    owner: www-data
    group: www-data
    mode: '0644'

- name: "Copiar fichero de configuración y reiniciar el servicio"
  copy:
    src: etc/apache2/ports.conf
    dest: /etc/apache2/ports.conf
    owner: root
    group: root
    mode: '0644'
  notify: restart apache2
```

En esta tarea si que se utilizan otros ficheros, pero al no tener una configuración crucial, no vamos a modificarlos. Su contenido se encuentra en github.

#### Cliente

Todas las tareas necesarias para que las máquinas conectadas a la red privada salgan a internet por eth1. El contenido de `tasks/main.yaml` es el siguiente:

```yaml
- name: cambiar la ruta por defecto
  shell: ip route delete default && ip route add default via 10.0.0.1 && echo "post-up route add -net 10.0.0.0 netmask 255.0.0.0 gw 10.0.0.0 dev eth1" >> /etc/network/interfaces
```

---

Finalmente, podemos ejecutar el playbook con `ansible-playbook site.yaml`:
![ansible](ansible.png)