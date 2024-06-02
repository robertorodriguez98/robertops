---
title: "Práctica 2: Interconexión de Servidores de Bases de Datos"
date: 2022-11-27T14:23:15+01:00
draft: false
media_subpath: /assets/2022-11-27-practica2-abd
image:
  path: featured.png
categories:
    - práctica
    - Administración de Bases de Datos
tags:
    - Oracle
    - Práctica 2 ABD
---

Las interconexiones de servidores de bases de datos son operaciones que pueden ser muy útiles en
diferentes contextos. Básicamente, se trata de acceder a datos que no están almacenados en nuestra base
de datos, pudiendo combinarlos con los que ya tenemos.
En esta práctica veremos varias formas de crear un enlace entre distintos servidores de bases de datos.
Se pide:

* Realizar un enlace entre dos servidores de bases de datos ORACLE, explicando la configuración
necesaria en ambos extremos y demostrando su funcionamiento.
* Realizar un enlace entre dos servidores de bases de datos Postgres, explicando la configuración
necesaria en ambos extremos y demostrando su funcionamiento.
* Realizar un enlace entre un servidor ORACLE y otro Postgres o MySQL empleando Heterogeneus
Services

## Enlace entre dos servidores ORACLE

En mi caso, las dos máquinas tienen la configuración siguiente; Tienen instalado Rocky 8 Oracle Database 19c Enterprise Edition, y tienen los siguientes nombres e IPs:

* oracle-maquina1: 192.168.122.204
* oracle-maquina2: 192.168.122.80

En ambas bases de datos existe el usuario roberto y están configuradas para el acceso remoto. Para comprobar que pueden acceder se utiliza el comando tnsping:

![1](https://i.imgur.com/gbnsKsB.png)

Ahora, para que los servidores puedan conectarse entre ellos, tenemos que añadir los datos de las máquinas al fichero `/opt/oracle/product/19c/dbhome_1/network/admin/tnsnames.ora`, dejándolos de la siguiente manera:

* En el fichero dentro de la máquina 1:

```ora
MAQUINA2 =
    (DESCRIPTION =
        (ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.122.80)(PORT = 1521))
        (CONNECT_DATA =
            (SERVER = DEDICATED)
            (SERVICE_NAME = ORCLCDB)
        )
    )
```

* En el fichero dentro de la máquina 2:

```ora
MAQUINA1 =
    (DESCRIPTION =
        (ADDRESS = (PROTOCOL = TCP)(HOST = 192.168.122.80)(PORT = 1521))
        (CONNECT_DATA =
            (SERVER = DEDICATED)
            (SERVICE_NAME = ORCLCDB)
        )
    )
```

Tras eso hay que crear los enlaces haciendo referencia al usuario (roberto). los comandos se ejecutan dentro de oracle:

* En la máquina 1:

```sql
create database link enlace2 connect to roberto identified by roberto using 'maquina2';
```

* En la máquina 2:

```sql
create database link enlace1 connect to roberto identified by roberto using 'maquina1';
```

Podemos comprobar que se puede acceder remotamente a las tablas:

![2](https://i.imgur.com/iYYIaiL.png)
![3](https://i.imgur.com/2Cu5V0W.png)

## Enlace entre dos servidores Postgres

En mi caso, las dos máquinas tienen la configuración siguiente; Tienen instalado Debian 11,MariaDB y PostgreSQL, y tienen los siguientes nombres e IPs:

* mariadb-maquina1: 192.168.122.97
* mariadb-maquina2: 192.168.122.90

En ambas bases de datos existe el usuario roberto y están configuradas para el acceso remoto.

Ahora vamos a crear el enlace:

```bash
apt install postgresql-contrib
psql -d scott
create extension dblink;
```

Una vez hecho eso, tenemos que ejecutar los siguientes comandos:

* Máquina 1:

```sql
SELECT dblink_connect('dblink2','dbname=scott host=192.168.122.90 user=roberto password=roberto');
```

* Máquina 2:

```sql
SELECT dblink_connect('dblink1','dbname=scott host=192.168.122.97 user=roberto password=roberto');
```

Tras eso, podemos realizar consultas entre máquinas:

![4](https://i.imgur.com/qzn6uGb.png)

---

## Enlace entre un servidor ORACLE y uno Postgres

En este caso las máquinas que voy a conectar son oracle-maquina1 y mariadb-maquina2, por lo que las direcciones IP son las siguientes:

* oracle-maquina1: 192.168.122.204
* mariadb-maquina2: 192.168.122.90

### Conexión desde Postgres a ORACLE

Primero descargamos los siguientes paquetes:

```bash
apt install libaio1 postgresql-server-dev-all build-essential git alien -y
```

Ahora tenemos que descargar el instantclient de oracle, se hace con los siguientes comandos:

```bash
wget https://download.oracle.com/otn_software/linux/instantclient/218000/oracle-instantclient-basic-21.8.0.0.0-1.el8.x86_64.rpm
wget https://download.oracle.com/otn_software/linux/instantclient/218000/oracle-instantclient-devel-21.8.0.0.0-1.el8.x86_64.rpm
wget https://download.oracle.com/otn_software/linux/instantclient/218000/oracle-instantclient-sqlplus-21.8.0.0.0-1.el8.x86_64.rpm

sudo alien -i --scripts oracle-instantclient-*
```

Una vez instalado, con el siguiente comando podemos conectarnos a la base de datos de oracle-maquina1:

```bash
sqlplus roberto/roberto@192.168.122.204:1521/ORCLCDB
```

Ahora tenemos que descargar y compilar `oracle_fdw`:

```bash
wget https://github.com/laurenz/oracle_fdw/archive/refs/tags/ORACLE_FDW_2_5_0.zip
unzip ORACLE_FDW_2_5_0.zip
```

Renombramos la carpeta:

```bash
mv oracle_fdw-ORACLE_FDW_2_5_0/ oracle_fdw
```

Finalmente compilamos el programa:

```bash
cd oracle_fdw
make
make install
```

Ahora, dentro de psql (y de la base de datos scott) creamos el enlace. Podemos comprobar que se ha creado con \dx:

```sql
CREATE EXTENSION oracle_fdw;
```

Creamos el schema en el que se van a importar las bases de datos de Oracle:

```sql
create schema oracle;
```

Configuramos un servidor foráneo que haga referencia a la base de datos Oracle en la otra máquina:

```sql
create server oracle foreign data wrapper oracle_fdw options (dbserver '//192.168.122.204/ORCLCDB');
```

Ahora creamos una equivalencia entre un usuario local y el del servidor (aunque en este caso se llaman igual):

```bash
create user mapping for roberto server oracle options (user 'roberto', password 'roberto');
```

Le damos permisos al usuario local sobre el schema de oracle:

```bash
grant all privileges on schema oracle to roberto;
grant all privileges on foreign server oracle to roberto;
```

Iniciamos sesión en psql con el usuario que hemos indicado en los pasos anteriores, e importamos el esquema remoto:

```bash
psql -U roberto -W -d scott
```

```bash
import foreign schema "ROBERTO" from server oracle into oracle;
```

![5](https://i.imgur.com/EypaWU0.png)

### Conexión desde Oracle a Postgres

Para realizar la conexión vamos a utilizar ODBC (Open Database Conectivity); y en este caso ya que vamos a realizar la conexión con PostgreSQL, también tenemos que descargar el paquete específico:

```bash
dnf install unixODBC postgresql-odbc
```

Ahora en el fichero de configuración `/etc/odbcinst.ini` comentamos todas las líneas menos las referentes a postgresql, quedando el fichero de la siguiente manera:

```bash
[PostgreSQL]
Description     = ODBC for PostgreSQL
Driver          = /usr/lib/psqlodbcw.so
Setup           = /usr/lib/libodbcpsqlS.so
Driver64        = /usr/lib64/psqlodbcw.so
Setup64         = /usr/lib64/libodbcpsqlS.so
FileUsage       = 1
```

Para configurar el acceso a la máquina con postgres tenemos que crear en el fichero `/etc/odbc.ini` la siguiente entrada:

```bash
[PSQLU]

Debug = 0
CommLog = 0
ReadOnly = 0
Driver = PostgreSQL
Servername = 192.168.122.90
Username = roberto
Password = roberto
Port = 5432
Database = scott
Trace = 0
TraceFile = /tmp/sql.log
```

Podemos comprobar que funciona con isql PSQLU.

Ahora hay que crear la configuración para que Oracle pueda hacer uso del driver. Para ello tenemos que crear el fichero `/opt/oracle/product/19c/dbhome_1/hs/admin/initPSQLU.ora` con el siguiente contenido:

```bash
HS_FDS_CONNECT_INFO = PSQLU
HS_FDS_TRACE_LEVEL = DEBUG
HS_FDS_SHAREABLE_NAME = /usr/lib64/psqlodbcw.so
HS_LANGUAGE = AMERICAN_AMERICA.WE8ISO8859P1
set ODBCINI=/etc/odbc.ini
```

También hay que configurar el listener `/opt/oracle/product/19c/dbhome_1/network/admin/listener.ora`, añadiendo lo siguiente al final:

```bash
SID_LIST_LISTENER =
    (SID_LIST =
        (SID_DESC =
            (SID_NAME = PSQLU)
            (ORACLE_HOME=/opt/oracle/product/19c/dbhome_1)
            (PROGRAM=dg4odbc)
        )
    )
```

Y añadimos una entrada de conexión a `/opt/oracle/product/19c/dbhome_1/network/admin/tnsnames.ora`:

```bash
PSQLU =
    (DESCRIPTION=
        (ADDRESS=(PROTOCOL=tcp)(HOST=localhost)(PORT=1521))
        (CONNECT_DATA=(SID=PSQLU))
        (HS=OK)
    )
```

Ahora reiniciamos el listener y creamos el enlace dentro de oracle.

```sql
create database link postgreslink connect to "roberto" identified by"roberto" using 'PSQLU';
```

Ya está creado el enlace. Ahora para comprobar que funciona, podemos hacer una consulta:

```sql
SELECT "ename" FROM "emp"@postgreslink;
```

![6](https://i.imgur.com/rSga9bn.png)