---
title: "Práctica 1 ABD"
date: 2022-10-31T01:05:11+01:00
draft: false
media_subpath: /assets/2022-10-31-practica1-abd
image:
  path: featured.png
categories:
    - práctica
    - Administración de Bases de Datos
tags:
    - MySQL
    - Apache
    - phpMyAdmin
    - Oracle
    - MariaDB
    - PostgreSQL
    - phpMyAdmin
    - rocky
    - Python
---

## Aplicación web MySQL

### Instalación

instalamos php:

```bash
apt install apache2 libapache2-mod-php php php-mysql
apt install php-zip php-gd php-mbstring phpmyadmin -y
```

### Configuración

En la instalación de phpmyadmin elegimos como servidor **apache2**, después, cuando nos pregunta por una contraseña, le damos a Sí, e introducimos una contraseña para phpmyadmin dos veces

Una vez instalado, para poder acceder con un usuario concreto, tenemos que hacer lo siguiente:

Entramos en el directorio de phpmyadmin y copiamos un fichero de ejemplo para utilizarlo como configuración:

```bash
cd /usr/share/phpmyadmin/
cp config.sample.inc.php config.inc.php
```

en el fichero `config.inc.php` tenemos que añadir a `blowfish_secret` una cadena de 30 caracteres, y tenemos que descomentar las lineas de `controluser`y `controlpass` y añadirles las credenciales.

![fichero_conf](fichero_conf.png)

Una vez realizada la configuración, reiniciamos el servicio:

```bash
systemctl reload apache2
```

### Prueba

y podemos acceder a la página de administración en `http://IPmaquina/phpmyadmin/`:

![login](login.png)
![home](home.png)
![tablas](tablas.png)

## Aplicación web Oracle

### Preparación

Antes de crear el fichero que va a ser la aplicación, vamos a crear un **Entorno virtual** (Venv) de python para contener ahí los módulos que nos descarguemos

```bash
mkdir aplicacion_web_oracle && cd aplicacion_web_oracle
python3 -m venv /home/roberto/aplicacion_web_oracle
source bin/activate
```

Ahora vamos a descargar los módulos necesarios:

```bash
pip install cx_oracle
pip install flask
```

Ahora, usando **flask**, se ha escrito la siguiente aplicación sencilla, que permite, al introducirle el nombre de un empleado en la dirección `/emp/`, mostrar los datos de dicho empleado. Es importante que, cuando se define **pool** se introduzcan los mismo datos que en el acceso remoto a oracle, ya que esta aplicación se ha creado desde una máquina distina a la de oracle.

```python
import os
import sys
import cx_Oracle
from flask import Flask

def init_session(connection, requestedTag_ignored):
    cursor = connection.cursor()
    cursor.execute("""
        ALTER SESSION SET
          TIME_ZONE = 'UTC'
          NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI'""")

# start_pool(): starts the connection pool
def start_pool():
    pool_min = 4
    pool_max = 4
    pool_inc = 0
    pool_gmd = cx_Oracle.SPOOL_ATTRVAL_WAIT

    print("Connecting to", "192.168.122.105:1521/ORCLCDB")

    pool = cx_Oracle.SessionPool(user="roberto",
                                 password="roberto",
                                 dsn="192.168.122.105:1521/ORCLCDB",
                                 min=pool_min,
                                 max=pool_max,
                                 increment=pool_inc,
                                 threaded=True,
                                 getmode=pool_gmd,
                                 sessionCallback=init_session)

    return pool

app = Flask(__name__)

@app.route('/')
def index():
    return "Entra en /emp/nombreempleado para ver los datos del empleado"


# Show the username for a given id
@app.route('/emp/<string:name>')
def show_username(name):
    connection = pool.acquire()
    cursor = connection.cursor()
    cursor.execute("select * from emp where ename = (:name)", [name])
    r = cursor.fetchone()
    r = str(r)
    return (r)

################################################################################
#
# Initialization is done once at startup time
#
if __name__ == '__main__':

    # Start a pool of connections
    pool = start_pool()


    # Start a webserver
    app.run(port=int(os.environ.get('PORT', '8080')))
```

![prueba1](prueba1.png)

![prueba2](prueba2.png)

## Conexiones desde clientes a servidores con bases de datos

Vamos a realizar conexiones desde los clientes de BBDD a sus respectivos servidores.

### Oracle

En el lado del servidor, tiene que estar activo oracle (`startup`), también como se ha hecho en la instalación tiene que estar activado el listener

```bash
lsnrctl start
```

 y el firewall tiene que permitir el puerto `1521`

```bash
firewall-cmd --permanent --add-port=1521/tcp
firewall-cmd --reload
```

Para conectarnos de manera remota a oracle, tenemos que descargar en el lado del cliente **instantclient**, del siguiente [enlace](https://www.oracle.com/es/database/technologies/instant-client/linux-x86-64-downloads.html). En él hay varios enlaces de descarga. Los que nos interesan son:

* https://download.oracle.com/otn_software/linux/instantclient/218000/oracle-instantclient-basic-21.8.0.0.0-1.el8.x86_64.rpm
* https://download.oracle.com/otn_software/linux/instantclient/218000/oracle-instantclient-devel-21.8.0.0.0-1.el8.x86_64.rpm
* https://download.oracle.com/otn_software/linux/instantclient/218000/oracle-instantclient-sqlplus-21.8.0.0.0-1.el8.x86_64.rpm

En mi caso, el cliente es debian, así que tenemos que instalar los paquetes usando alien:

```bash
sudo alien -i --scripts oracle-instantclient-*
```

Una vez instalados, podemos acceder al servidor con `sqlplus`, donde la sintaxis es

```bash
sqlplus [USUARIO]/[CONTRASEÑA]@[IP:PUERTO]/[NOMBREBD]
```

```bash
sqlplus roberto/roberto@192.168.122.105:1521/ORCLCDB
```

![oracle](oracle.png)

En la captura se puede ver una consulta de prueba para comprobar que se ha accedido a la base de datos correctamente.

### MariaDB

Para conectarnos tenemos que instalar el paquete `mariadb-client`:

```bash
sudo apt install mariadb-client
```

Una vez instalado, ya podemos acceder al servidor. El comando tiene la siguiente sintaxis:

```bash
mariadb --host FULLY_QUALIFIED_DOMAIN_NAME --port TCP_PORT \
     --user DATABASE_USER --password \
     --ssl-verify-server-cert \
     --ssl-ca PATH_TO_PEM_FILE
```

Lo utilizamos con las opciones de nuestro servidor:

```bash
mariadb --host 192.168.122.78 --port 3306 \
--user remoto --password
```

![mariadb](mariadb.png)

### PostgreSQL

Para conectarnos tenemos que instalar el paquete `postgresql-client`

```bash
sudo apt install postgresql-client
```

Y nos conectamos al servidor usando el comando `psql`:

```bash
psql --host 192.168.122.78 --user roberto -d scott
```

![postgre](postgre.png)

## Instalación de MariaDB y PostgreSQL en Debian

### MariaDB

El paquete de MariaDB se encuentra en los repositorios de Debian, por lo que podemos instalarlo directamente con apt:

```bash
sudo apt update
sudo apt install mariadb-server -y 
```

Entramos en la base de datos como root:

```bash
mysql -u root -p
```

#### Configuración para acceso remoto

Para poder acceder remotamente tenemos que modificar el archivo de configuración `/etc/mysql/mariadb.conf.d/50-server.cnf`, buscando la línea de **bind-address** y poniendo lo siguiente:

```bash
bind-address            = 0.0.0.0
```

A continuación reiniciamos el servicio de mariadb:

```bash
systemctl restart mariadb.service
```

Dentro de mariadb, tenemos que crear un usuario para el acceso remoto (el `%` es un comodín para indicar que se pueda acceder desde cualquier dirección):

```sql
GRANT ALL PRIVILEGES ON *.* TO 'remoto'@'%'
IDENTIFIED BY 'remoto' WITH GRANT OPTION;
```

#### Creación de usuario

Creamos un usuario con todos los privilegios:

```bash
GRANT ALL PRIVILEGES ON *.* TO 'roberto'@'localhost'
IDENTIFIED BY 'roberto' WITH GRANT OPTION;
```

Ahora podemos entrar con el usuario roberto:

```bash
mysql -u roberto -p
```

#### Creación de tablas

Vamos a crear el esquema scott en mysql:

```sql
create database scott;
use scott;
```

```sql
CREATE TABLE IF NOT EXISTS `dept` (
  `DEPTNO` int(11) DEFAULT NULL,
  `DNAME` varchar(14) DEFAULT NULL,
  `LOC` varchar(13) DEFAULT NULL
);
INSERT INTO `dept` (`DEPTNO`, `DNAME`, `LOC`) VALUES
(10, 'ACCOUNTING', 'NEW YORK'),
(20, 'RESEARCH', 'DALLAS'),
(30, 'SALES', 'CHICAGO'),
(40, 'OPERATIONS', 'BOSTON');
CREATE TABLE IF NOT EXISTS `emp` (
  `EMPNO` int(11) NOT NULL,
  `ENAME` varchar(10) DEFAULT NULL,
  `JOB` varchar(9) DEFAULT NULL,
  `MGR` int(11) DEFAULT NULL,
  `HIREDATE` date DEFAULT NULL,
  `SAL` int(11) DEFAULT NULL,
  `COMM` int(11) DEFAULT NULL,
  `DEPTNO` int(11) DEFAULT NULL
);
INSERT INTO `emp` (`EMPNO`, `ENAME`, `JOB`, `MGR`, `HIREDATE`, `SAL`, `COMM`, `DEPTNO`) VALUES
(7369, 'SMITH', 'CLERK', 7902, '1980-12-17', 800, NULL, 20),
(7499, 'ALLEN', 'SALESMAN', 7698, '1981-02-20', 1600, 300, 30),
(7521, 'WARD', 'SALESMAN', 7698, '1981-02-22', 1250, 500, 30),
(7566, 'JONES', 'MANAGER', 7839, '1981-04-02', 2975, NULL, 20),
(7654, 'MARTIN', 'SALESMAN', 7698, '1981-09-28', 1250, 1400, 30),
(7698, 'BLAKE', 'MANAGER', 7839, '1981-05-01', 2850, NULL, 30),
(7782, 'CLARK', 'MANAGER', 7839, '1981-06-09', 2450, NULL, 10),
(7788, 'SCOTT', 'ANALYST', 7566, '1982-12-09', 3000, NULL, 20),
(7839, 'KING', 'PRESIDENT', NULL, '1981-11-17', 5000, NULL, 10),
(7844, 'TURNER', 'SALESMAN', 7698, '1980-09-08', 1500, 0, 30),
(7876, 'ADAMS', 'CLERK', 7788, '1983-01-12', 1100, NULL, 20),
(7900, 'JAMES', 'CLERK', 7698, '1981-12-03', 950, NULL, 30),
(7902, 'FORD', 'ANALYST', 7566, '1981-12-03', 3000, NULL, 20),
(7934, 'MILLER', 'CLERK', 7782, '1982-01-23', 1300, NULL, 10);
```

### PostgreSQL

El paquete de PostgreSQL se encuentra en los repositorios de Debian, por lo que podemos instalarlo directamente con apt:

```bash
sudo apt install postgreSQL
```

Accedemos al usuario postgres:

```bash
su postgres
```

#### Configuración para acceso remoto

Para poder acceder remotamente tenemos que modificar el archivo de configuración `/etc/postgresql/13/main/postgresql.conf`, buscando la línea de **listen_addresses** y poniendo lo siguiente:

```bash
listen_addresses = '*'
```

También, al final del fichero `/etc/postgresql/13/main/pg_hba.conf` tenemos que añadir las siguientes líneas:

```bash
host    all      all              0.0.0.0/0                    md5
host    all      all              ::/0                         md5
```

Reiniciamos el servicio para que los cambios tengan efecto:

```bash
systemctl restart postgresql.service
```

Ahora vamos a crear un usuario con contraseña para acceder desde fuera con el siguiente comando dentro de `psql`:

```sql
create user roberto with superuser password 'roberto';
```

#### Creación de tablas

Creamos la base de datos y accedemos a `psql`

```bash
createdb scott
psql
```

Dentro del intérprete de comandos añadimos el esquema scott:

```sql
\c scott

create table dept (
  deptno integer,
  dname  text,
  loc    text,
  constraint pk_dept primary key (deptno)
);
create table emp (
  empno    integer,
  ename    text,
  job      text,
  mgr      integer,
  hiredate date,
  sal      integer,
  comm     integer,
  deptno   integer,
  constraint pk_emp primary key (empno),
  constraint fk_mgr foreign key (mgr) references emp (empno),
  constraint fk_deptno foreign key (deptno) references dept (deptno)
);
insert into dept (deptno,  dname,        loc)
       values    (10,     'ACCOUNTING', 'NEW YORK'),
                 (20,     'RESEARCH',   'DALLAS'),
                 (30,     'SALES',      'CHICAGO'),
                 (40,     'OPERATIONS', 'BOSTON');
insert into emp (empno, ename,    job,        mgr,   hiredate,     sal, comm, deptno)
       values   (7369, 'SMITH',  'CLERK',     7902, '1980-12-17',  800, NULL,   20),
                (7499, 'ALLEN',  'SALESMAN',  7698, '1981-02-20', 1600,  300,   30),
                (7521, 'WARD',   'SALESMAN',  7698, '1981-02-22', 1250,  500,   30),
                (7566, 'JONES',  'MANAGER',   7839, '1981-04-02', 2975, NULL,   20),
                (7654, 'MARTIN', 'SALESMAN',  7698, '1981-09-28', 1250, 1400,   30),
                (7698, 'BLAKE',  'MANAGER',   7839, '1981-05-01', 2850, NULL,   30),
                (7782, 'CLARK',  'MANAGER',   7839, '1981-06-09', 2450, NULL,   10),
                (7788, 'SCOTT',  'ANALYST',   7566, '1982-12-09', 3000, NULL,   20),
                (7839, 'KING',   'PRESIDENT', NULL, '1981-11-17', 5000, NULL,   10),
                (7844, 'TURNER', 'SALESMAN',  7698, '1981-09-08', 1500,    0,   30),
                (7876, 'ADAMS',  'CLERK',     7788, '1983-01-12', 1100, NULL,   20),
                (7900, 'JAMES',  'CLERK',     7698, '1981-12-03',  950, NULL,   30),
                (7902, 'FORD',   'ANALYST',   7566, '1981-12-03', 3000, NULL,   20),
                (7934, 'MILLER', 'CLERK',     7782, '1982-01-23', 1300, NULL,   10);
```

### MongoDB

Como indica la [documentación oficial](https://www.mongodb.com/docs/v6.0/tutorial/install-mongodb-on-debian/), Primero tenemos que añadir la clave a nuestros repositorios:

```bash
sudo apt install gnupg gnupg2 gnupg1
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
```

Ahora añadimos el repositorio de mongo a los repositorios de debian:

```bash
echo "deb http://repo.mongodb.org/apt/debian buster/mongodb-org/6.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
```

Y ahora, con los repositorios ya añadidos, instalamos mongodb:

```bash
sudo apt update
sudo apt install -y mongodb-org
```

Una vez instalado, iniciamos el servicio y activamos el inicio automático:

```bash
sudo systemctl start mongod
sudo systemctl enable mongod
```

#### Configuración de acceso remoto

Tenemos que editar el fichero `/etc/mongod.conf` y comentar la línea `bindIP`:

```bash
# bindIp: 127.0.0.1
```

y reiniciamos el servicio

```bash
sudo systemctl restart mongod
```

#### Creación de documentos

En este caso voy a insertar los datos de mi [proyecto de MongoDB](https://github.com/robertorodriguez98/proyectoMongoDB/)

```bash
mongoimport --db=yugioh --collection=prankkids --jsonArray --type json --file=prankkids.json
```

Podemos hacer una consulta para comprobar que se ha creado correctamente:

```sql
use yugioh
db.prankkids.find({"card_sets.set_name":"Hidden Summoners"}).count()
```

![mongo](mongo.png)

## Instalación Oracle 19c en Rocky linux 8

Se va a realizar la instalación de Oracle 19c en Rocky linux 8, debido a su mayor compatibilidad con el programa y menor número de fallos que con Debian 11.

### Pasos previos

Los siguientes pasos se deben ejecutar como usuario **root**.
Actualizamos el sistema:

```bash
dnf makecache
dnf update -y
```

Si al ejecutarlo se actualiza el **kernel**, deberíamos reiniciar la máquina.


como indica la [documentación](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/running-rpm-packages-to-install-oracle-database.html#GUID-BB7C11E3-D385-4A2F-9EAF-75F4F0AACF02), instalamos los requisitos previos. Sin embargo, al no estar en centos 7, tenemos que instalar manualmente unos paquetes

```bash
dnf install -y bc binutils compat-openssl10 elfutils-libelf glibc glibc-devel ksh libaio libXrender libX11 libXau libXi libXtst libgcc libnsl libstdc++ libxcb libibverbs make policycoreutils policycoreutils-python-utils smartmontools sysstat libnsl2 net-tools nfs-utils unzip
dnf install -y http://mirror.centos.org/centos/7/os/x86_64/Packages/compat-libcap1-1.10-7.el7.x86_64.rpm
dnf install -y http://mirror.centos.org/centos/7/os/x86_64/Packages/compat-libstdc++-33-3.2.3-72.el7.x86_64.rpm
```

Después descargamos los requisitos previos y los instalamos:

```bash
curl -o oracle-database-preinstall-19c-1.0-1.el7.x86_64.rpm https://yum.oracle.com/repo/OracleLinux/OL7/latest/x86_64/getPackage/oracle-database-preinstall-19c-1.0-1.el7.x86_64.rpm
yum -y localinstall oracle-database-preinstall-19c-1.0-1.el7.x86_64.rpm
```

Configuramos el firewall

```bash
firewall-cmd --permanent --add-port=1521/tcp
firewall-cmd --reload
```

configuramos el **target mode** de SELinux a permisivo:

```bash
sed -i 's/^SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config
setenforce permissive
```

### Instalación

Ahora descargamos el paquete rpm de la [página oficial de oracle](https://www.oracle.com/es/database/technologies/oracle19c-linux-downloads.html):

![descarga](descarga.png)

```bash
yum -y localinstall oracle-database-ee-19c-1.0-1.x86_64.rpm 
```

![instalacion](instalacion.png)

Como nos indica al final de la instalación, creamos la base de datos de pruebas ejecutando el siguiente script:

```bash
/etc/init.d/oracledb_ORCLCDB-19c configure
```

![script](script.png)

Tras la ejecución, tenemos que iniciar sesión con el usuario **oracle** que se ha creado durante la misma, Y añadirle las siguientes variables al fichero `.bash_profile`

```bash
umask 022
export ORACLE_SID=ORCLCDB
export ORACLE_BASE=/opt/oracle/oradata
export ORACLE_HOME=/opt/oracle/product/19c/dbhome_1
export PATH=$PATH:$ORACLE_HOME/bin
```

Recargamos el fichero para que las variables tengan efecto:

```bash
source ~/.bash_profile
```

Tras este paso ya está instalado **oracle**, Ahora sigue crear la base de datos. Primero activamos el listener:

```bash
lsnrctl start
```

Para facilitar la utilización de `sqlplus` vamos a instalar el paquete `rlwrap`, que permite que utilicemos el cursor, tanto para desplazarnos por las líneas como para rescatar comandos.

```bash
dnf install epel-release
dnf install rlwrap -y
```

ahora creamos el siguiente alias en `~/.bashrc`:

```bash
alias sqlplus='rlwrap sqlplus'
```

### Configuración

Primero nos conectamos a la base de datos como **sysdba**:

```bash
sqlplus / as sysdba
```

y podemos comprobar la versión de oracle con la siguiente consulta:

```sql
SELECT instance_name, host_name, version, startup_time FROM v$instance;
```

![versionora](versionora.png)

#### Creación de usuario con privilegios

Vamos a crear un usuario para poder acceder a la base de datos sin utilizar el **sysdba**, con los siguientes comandos. Antes de crear el usuario, tenemos  que activar `_ORACLE_SCRIPT` para que se puedan ejecutar sin errores los siguientes comandos:

```sql
alter session set "_ORACLE_SCRIPT"=true;
CREATE USER roberto IDENTIFIED BY roberto;
GRANT ALL PRIVILEGES TO roberto;
```

Una vez creado el usuario podemos conectarnos con él utilizando el siguiente comando:

```bash
sqlplus roberto/roberto
```

### Creación de tablas

Vamos a introducir a modo de prueba, el esquema **scott**:

```sql
CREATE TABLE DEPT
(
 DEPTNO NUMBER(2),
 DNAME VARCHAR2(14),
 LOC VARCHAR2(13),
 CONSTRAINT PK_DEPT PRIMARY KEY (DEPTNO)
);
CREATE TABLE EMP
(
 EMPNO NUMBER(4),
 ENAME VARCHAR2(10),
 JOB VARCHAR2(9),
 MGR NUMBER(4),
 HIREDATE DATE,
 SAL NUMBER(7, 2),
 COMM NUMBER(7, 2),
 DEPTNO NUMBER(2),
 CONSTRAINT FK_DEPTNO FOREIGN KEY (DEPTNO) REFERENCES DEPT (DEPTNO),
 CONSTRAINT PK_EMP PRIMARY KEY (EMPNO)
);
INSERT INTO DEPT VALUES (10, 'ACCOUNTING', 'NEW YORK');
INSERT INTO DEPT VALUES (20, 'RESEARCH', 'DALLAS');
INSERT INTO DEPT VALUES (30, 'SALES', 'CHICAGO');
INSERT INTO DEPT VALUES (40, 'OPERATIONS', 'BOSTON');
INSERT INTO EMP VALUES(7369, 'SMITH', 'CLERK', 7902,TO_DATE('17-DIC-1980', 'DD-MON-YYYY'), 800, NULL, 20);
INSERT INTO EMP VALUES(7499, 'ALLEN', 'SALESMAN', 7698,TO_DATE('20-FEB-1981', 'DD-MON-YYYY'), 1600, 300, 30);
INSERT INTO EMP VALUES(7521, 'WARD', 'SALESMAN', 7698,TO_DATE('22-FEB-1981', 'DD-MON-YYYY'), 1250, 500, 30);
INSERT INTO EMP VALUES(7566, 'JONES', 'MANAGER', 7839,TO_DATE('2-ABR-1981', 'DD-MON-YYYY'), 2975, NULL, 20);
INSERT INTO EMP VALUES(7654, 'MARTIN', 'SALESMAN', 7698,TO_DATE('28-SEP-1981', 'DD-MON-YYYY'), 1250, 1400, 30);
INSERT INTO EMP VALUES(7698, 'BLAKE', 'MANAGER', 7839,TO_DATE('1-MAY-1981', 'DD-MON-YYYY'), 2850, NULL, 30);
INSERT INTO EMP VALUES(7782, 'CLARK', 'MANAGER', 7839,TO_DATE('9-JUN-1981', 'DD-MON-YYYY'), 2450, NULL, 10);
INSERT INTO EMP VALUES(7788, 'SCOTT', 'ANALYST', 7566,TO_DATE('09-DIC-1982', 'DD-MON-YYYY'), 3000, NULL, 20);
INSERT INTO EMP VALUES(7839, 'KING', 'PRESIDENT', NULL,TO_DATE('17-NOV-1981', 'DD-MON-YYYY'), 5000, NULL, 10);
INSERT INTO EMP VALUES(7844, 'TURNER', 'SALESMAN', 7698,TO_DATE('8-SEP-1981', 'DD-MON-YYYY'), 1500, 0, 30);
INSERT INTO EMP VALUES(7876, 'ADAMS', 'CLERK', 7788,TO_DATE('12-ENE-1983', 'DD-MON-YYYY'), 1100, NULL, 20);
INSERT INTO EMP VALUES(7900, 'JAMES', 'CLERK', 7698,TO_DATE('3-DIC-1981', 'DD-MON-YYYY'), 950, NULL, 30);
INSERT INTO EMP VALUES(7902, 'FORD', 'ANALYST', 7566,TO_DATE('3-DIC-1981', 'DD-MON-YYYY'), 3000, NULL, 20);
INSERT INTO EMP VALUES(7934, 'MILLER', 'CLERK', 7782,TO_DATE('23-ENE-1982', 'DD-MON-YYYY'), 1300, NULL, 10);

COMMIT;
```

Las tablas se crean sin errores y se introducen los valores. Podemos realizar una consulta sencilla:

```sql
SELECT ename
FROM emp
WHERE deptno = (SELECT deptno
                FROM dept
                WHERE dname = 'SALES');
```

![consulta](consulta.png)