---
title: "Administración de Bases de Datos - Auditoria"
date: 2023-02-21T08:27:43+01:00
draft: false
media_subpath: /assets/2023-02-21-auditoria
image:
  path: featured.png
categories:
    - documentación
    - Administración de Bases de Datos
tags:
    - Auditoría
    - Oracle
    - Postgres
    - MongoDB
---

## Activa desde SQL*Plus la auditoría de los intentos de acceso exitosos al sistema. Comprueba su funcionamiento

Para activar la auditoría y que los datos se almacenen en la base de datos, ejecutamos el siguiente comando:

```sql
ALTER SYSTEM SET audit_trail=db scope=spfile;
```

Para comprobar que se ha activado correctamente, ejecutamos el siguiente comando:

```sql
SELECT name, value FROM v$parameter WHERE name like 'audit_trail';
```

![audit_trail](https://i.imgur.com/juhQKXU.png)

Para activar la auditoría de los intentos de acceso exitosos al sistema, ejecutamos el siguiente comando:

```sql
AUDIT CREATE SESSION WHENEVER SUCCESSFUL;
```

Ahora, tras acceder a la base de datos con el usuario restaurante (de una práctica anterior), haciendo la siguiente consulta, puedo ver que se ha almacenado la información del acceso:

```sql
SELECT OS_USERNAME, USERNAME, EXTENDED_TIMESTAMP, ACTION_NAME FROM DBA_AUDIT_SESSION;
```

![auditoria](https://i.imgur.com/Y0qJUmC.png)


## Realiza un procedimiento en PL/SQL que te muestre los accesos fallidos junto con el motivo de los mismos, transformando el código de error almacenado en un mensaje de texto comprensible. Contempla todos los motivos posibles para que un acceso sea fallido

Primero, para vaciar la tabla de auditoría, ejecuto el siguiente comando:

```sql
TRUNCATE table sys.AUD$;
```

Ahora creo una sesión de auditoría para los accesos fallidos:

```sql
AUDIT CREATE SESSION WHENEVER NOT SUCCESSFUL;
```

He obtenido el significado de los códigos de error de la siguiente página: <http://johanlouwers.blogspot.com/2013/01/oracle-database-login-audit.html>

| Código | Significado |
|:-:|---|
|00911|El nombre de usuario o la contraseña contiene un carácter no válido|
|00988|Falta la contraseña o no es válida|
|01004|Inicio de sesión denegado|
|01005|Contraseña nula|
|01017|Contraseña / usuario no válidos|
|01031|Sin privilegios|
|01045|El usuario no tiene el privilegio CREATE SESSION|
|01918|No existe el user ID|
|01920|No existe el rol|
|09911|Contraseña incorrecta|
|28000|La cuenta está bloqueada|
|28001|La contraseña ha caducado|
|28002|La contraseña caducará pronto, se debe cambiar ahora|
|28003|La contraseña no es lo suficientemente compleja|
|28007|La contraseña no se puede reutilizar|
|28008|Contraseña antigua no válida|
|28009|La conexión a sys se debe realizar desde sysdba o sysoper|
|28011|La cuenta va a caducar pronto, se debe cambiar la contraseña|
|28221|La contraseña original no ha sido suministrada|

Ahora, creo el procedimiento en PL/SQL:

```sql
CREATE OR REPLACE PROCEDURE accesosFallidos
IS
    CURSOR c_accesos IS
        SELECT USERNAME, EXTENDED_TIMESTAMP, ACTION_NAME, RETURNCODE
        FROM DBA_AUDIT_SESSION
        WHERE RETURNCODE <> 0;
begin
    for i in c_accesos loop
        dbms_output.put_line('HORA: ' || i.EXTENDED_TIMESTAMP);
        dbms_output.put_line(CHR(9)||'-USUARIO: ' || i.USERNAME);
        case i.RETURNCODE
            when 00911 then
                dbms_output.put_line(CHR(9)||'-El nombre de usuario o la contrasena contiene un caracter no valido');
            when 00988 then
                dbms_output.put_line(CHR(9)||'-Falta la contrasena o no es valida');
            when 01004 then
                dbms_output.put_line(CHR(9)||'-Inicio de sesion denegado');
            when 01005 then
                dbms_output.put_line(CHR(9)||'-contrasena nula');
            when 01017 then
                dbms_output.put_line(CHR(9)||'-contrasena / usuario no validos');
            when 01031 then
                dbms_output.put_line(CHR(9)||'-Sin privilegios');
            when 01045 then
                dbms_output.put_line(CHR(9)||'-El usuario no tiene el privilegio CREATE SESSION');
            when 01918 then
                dbms_output.put_line(CHR(9)||'-No existe el user ID');
            when 01920 then
                dbms_output.put_line(CHR(9)||'-No existe el rol');
            when 09911 then
                dbms_output.put_line(CHR(9)||'-contrasena incorrecta');
            when 28000 then
                dbms_output.put_line(CHR(9)||'-La cuenta esta bloqueada');
            when 28001 then
                dbms_output.put_line(CHR(9)||'-La contrasena ha caducado');
            when 28002 then
                dbms_output.put_line(CHR(9)||'-La contrasena caducara pronto, se debe cambiar ahora');
            when 28003 then
                dbms_output.put_line(CHR(9)||'-La contrasena no es lo suficientemente compleja');
            when 28007 then
                dbms_output.put_line(CHR(9)||'-La contrasena no se puede reutilizar');
            when 28008 then
                dbms_output.put_line(CHR(9)||'-contrasena antigua no valida');
            when 28009 then
                dbms_output.put_line(CHR(9)||'-La conexión a sys se debe realizar desde sysdba o sysoper');
            when 28011 then
                dbms_output.put_line(CHR(9)||'-La cuenta va a caducar pronto, se debe cambiar la contrasena');
            when 28221 then
                dbms_output.put_line(CHR(9)||'-La contrasena original no ha sido suministrada');
        end case;
    end loop;
end;
/
```

Compruebo que funciona correctamente:

![accesosFallidos](https://i.imgur.com/FGHbSQV.png)

## Activa la auditoría de las operaciones DML realizadas por SCOTT. Comprueba su funcionamiento

Activo la auditoría de las operaciones DML realizadas por SCOTT:

```sql
AUDIT INSERT TABLE, UPDATE TABLE, DELETE TABLE BY SCOTT BY ACCESS;
```

Ahora inserto un empleado en la tabla emp:

```sql
INSERT INTO emp VALUES (9999, 'Roberto', 'Director', 7839, TO_DATE('21/02/2023', 'DD/MM/YYYY'), 5000, 0, 10);
```

Y se ve reflectado en la tabla de auditoría:

```sql
SELECT USERNAME, OBJ_NAME, ACTION_NAME, EXTENDED_TIMESTAMP FROM DBA_AUDIT_OBJECT;
```

![auditoriaDML](https://i.imgur.com/33VAXWP.png)

## Realiza una auditoría de grano fino para almacenar información sobre la inserción de empleados con sueldo superior a 2000 en la tabla emp de scott

La auditoría de grano fino (FGA) es como una versión extendida de la auditoría estándar. Registra los cambios en datos muy concretos a nivel de columna.

Para realizar la auditoría de grano fino, primero tengo que crear una política de auditoría:

```sql
BEGIN
    DBMS_FGA.ADD_POLICY (
    OBJECT_SCHEMA      => 'SCOTT',
    OBJECT_NAME        => 'EMP',
    POLICY_NAME        => 'SALARIO_MAYOR_2000',
    AUDIT_CONDITION    => 'SAL < 2000',
    STATEMENT_TYPES    => 'INSERT'
    );
END;
/
```

Ahora inserto varios empleados:

```sql
INSERT INTO emp VALUES (2222, 'Bill Gates', 'Director', 7839, TO_DATE('21/02/2023', 'DD/MM/YYYY'), 1000, 0, 10);
INSERT INTO emp VALUES (3333, 'Steve Jobs', 'Director', 7839, TO_DATE('21/02/2023', 'DD/MM/YYYY'), 5000, 0, 10);
```

![auditoriaGranoFino](https://i.imgur.com/rqLZNLq.png)

Y compruebo que aparece en la tabla de auditoría:

```sql
SELECT DB_USER, OBJECT_NAME, SQL_TEXT, EXTENDED_TIMESTAMP FROM DBA_FGA_AUDIT_TRAIL WHERE POLICY_NAME='SALARIO_MAYOR_2000';
```

![auditoriaGranoFino](https://i.imgur.com/EseLG8U.png)

## Explica la diferencia entre auditar una operación by access o by session ilustrándolo con ejemplos

Las operaciones by access se auditan por cada acceso a la base de datos, mientras que las operaciones by session se auditan por cada sesión de usuario. Por ejemplo, si un usuario realiza 10 accesos a la base de datos, se auditarán 10 operaciones by access, mientras que si realiza 10 accesos en una misma sesión, se auditarán 1 operación by session.

La sintaxis es la siguiente:

```sql
AUDIT [operación] [tabla] BY [usuario] BY {ACCESS | SESSION};
```

## Documenta las diferencias entre los valores db y db, extended del parámetro audit_trail de ORACLE. Demuéstralas poniendo un ejemplo de la información sobre una operación concreta recopilada con cada uno de ellos

Ambos parámetros indican que la auditoría está activada. La diferencia es que el parámetro db guarda la información en la tabla de auditoría, mientras que el parámetro db, extended guarda la información en la tabla de auditoría y en el archivo de alerta.

Para cambiar el parámetro, utilizo el siguiente comando:

```sql
ALTER SYSTEM SET audit_trail = db, extended SCOPE = SPFILE;
```

Reinicio la base de datos y compruebo que el parámetro se ha cambiado correctamente, con la consulta del ejercicio 1:

![auditTrail](https://i.imgur.com/sIytDAc.png)

## Averigua si en Postgres se pueden realizar los cuatro primeros apartados. Si es así, documenta el proceso adecuadamente

### Ejercicio 1

En postgres no se puede realizar el ejercicio 1, ya que se registran los inicios de sesión fallidos en el archivo de log, pero no los exitosos.

### Ejercicio 2

No se puede realizar un procedimiento ya que los accesos fallidos no está registrado en la base de datos, sino en el archivo de log, sin embargo, en el propio archivo de log, se encuentran explicados con palabras y en español, el objetivo final del procedimiento:

![accesosFallidos](https://i.imgur.com/n9IuvtS.png)

### Ejercicio 3

Para realizar la auditoría voy a usar **Trigger 91plus**, una herramienta creada por la comunidad que permite auditar las operaciones DML en postgres.

Para instalarla, primero tengo que descargar de github el siguiente fichero

```bash
wget https://raw.githubusercontent.com/2ndQuadrant/audit-trigger/master/audit.sql
```

Y luego lo instalo:

```sql
\i audit.sql
```

![instalacionTrigger](https://i.imgur.com/yYJq9ye.png)

No puede realizar auditorías de todo lo que realiza un usuario, sino de tablas. Por lo que voy a especificar las tablas del usuario scott que quiero auditar:

```sql
SELECT audit.audit_table('scott.emp');
SELECT audit.audit_table('scott.dept');
```

## Averigua si en MySQL se pueden realizar los apartados 1, 3 y 4. Si es así, documenta el proceso adecuadamente

### Ejercicio 1

Para obtener los datos de los inicios de sesión, edito el fichero `/etc/mysql/mariadb.conf.d/50-server.cnf`:

```bash
general_log_file       = /var/log/mysql/mysql.log
general_log            = 1
log_error = /var/log/mysql/error.log
```

Cambio el propietario del directorio de los logs y reinicio el servicio:

```bash
chown -R mysql:mysql /var/log/mysql
systemctl restart mariadb.service
```

Ahora, tras varios inicios de sesión, compruebo el fichero de logs `/var/log/mysql/mysql.log`:

![mysqlLog](https://i.imgur.com/fpOjaLH.png)

### Ejercicio 3

Para realizar la auditoría voy a instalar el plugin `server_audit`:

```sql
INSTALL SONAME 'server_audit';
```

Ahora edito el fichero `/etc/mysql/mariadb.conf.d/50-server.cnf` y reinicio mariadb:

```bash
[server]
server_audit_events=CONNECT,QUERY,TABLE
server_audit_logging=ON
server_audit_incl_users=scott
```

Tras insertar un nuevo empleado, compruebo el fichero de log `/var/lib/mysql/server_audit.log`:

![mysqlLog](https://i.imgur.com/GAOO4Kz.png)

## Averigua las posibilidades que ofrece MongoDB para auditar los cambios que va sufriendo un documento. Demuestra su funcionamiento

Para realizar las auditorías, es necesario instalar la versión Enterprise. La documentación de instalación oficial se encuentra en el siguiente enlace [https://www.mongodb.com/docs/manual/tutorial/install-mongodb-enterprise-on-debian/](https://www.mongodb.com/docs/manual/tutorial/install-mongodb-enterprise-on-debian/). Una vez instalado podemos hacer lo siguiente:

- Habilitar las auditorías en el syslog desde la consola:

```bash
mongod --dbpath /var/lib/mongodb/ --auditDestination syslog
```

- Habilitar las auditorías en un fichero JSON desde la consola:

```bash
mongod --dbpath /var/lib/mongodb/ --auditDestination file --auditFormat JSON --auditPath /var/lib/mongodb/auditLog.json
```

- Habilitar las auditorías en un fichero BSON desde la consola:

```bash
mongod --dbpath /var/lib/mongodb/ --auditDestination file --auditFormat BSON --auditPath /var/lib/mongodb/auditLog.bson
```

- Habilitar las auditorías en la consola desde la consola:

```bash
mongod --dbpath /var/lib/mongodb/ --auditDestination console
```

He utilizado la salida por consola y preferencia de formato ya que se trata también de un json. 

```bash
mongod --dbpath /var/lib/mongodb/ --auditDestination console | jq
```

![mongoAudit](https://i.imgur.com/DNdM1aZ.png)

##. Averigua si en MongoDB se pueden auditar los accesos a una colección concreta. Demuestra su funcionamiento
