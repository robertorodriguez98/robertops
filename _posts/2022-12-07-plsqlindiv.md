---
title: "Práctica PL/SQL individual"
date: 2022-12-07T13:37:02+01:00
draft: false
media_subpath: /assets/2022-12-07-plsqlindiv
image:
  path: featured.png
categories:
    - documentación
    - Administración de Bases de Datos
tags:
    - Oracle
    - PL/SQL
---

##  Hacer un procedimiento que muestre el nombre y el salario del empleado cuyo código es 7782

```sql
CREATE OR REPLACE PROCEDURE mostrarnombresalario
is
    v_nombre emp.ename%type;
    v_salario emp.sal%type;
begin
    select ename,sal into v_nombre,v_salario from emp where empno=7782;
    dbms_output.put_line('El nombre del empleado es ' || v_nombre || ' y su salario es: ' || v_salario);
end;
/
```

![p1](https://i.imgur.com/CscMTfL.png)

##  Hacer un procedimiento que reciba como parámetro un código de empleado y devuelva su nombre

```sql
CREATE OR REPLACE PROCEDURE mostrarnombresalario2 (p_empno emp.empno%TYPE)
is
    v_nombre emp.ename%type;
    v_salario emp.sal%type;
begin
    select ename,sal into v_nombre,v_salario from emp where empno=p_empno;
    dbms_output.put_line('El nombre del empleado es ' || v_nombre || ' y su salario es: ' || v_salario);
end;
/
```

![p2](https://i.imgur.com/o2tqMaP.png)

##  Hacer un procedimiento que devuelva los nombres de los tres empleados más antiguos

```sql
CREATE OR REPLACE PROCEDURE topantiguos
is
    cursor c_top is
        select ename
        from emp
        order by hiredate asc
        fetch first 3 rows only;
begin
    dbms_output.put_line('Los 3 empleados mas antiguos son: ');
    for v_empleado in c_top loop
        dbms_output.put_line(v_empleado.ename);
    end loop;
end;
/
```

![p3](https://i.imgur.com/FOSjg5a.png)

##  Hacer un procedimiento que reciba el nombre de un tablespace y muestre los nombres de los usuarios que lo tienen como tablespace por defecto (Vista DBA_USERS)

```sql
CREATE OR REPLACE PROCEDURE verusuarios (p_tablespace dba_users.default_tablespace%type)
is
    cursor c_usuarios is
        SELECT username
        from dba_users
        where default_tablespace=p_tablespace;
begin
    dbms_output.put_line('El tablespace ' || p_tablespace || ' es el predeterminado de los siguientes usuarios:');
    for v_usuario in c_usuarios loop
        dbms_output.put_line(v_usuario.username);
    end loop;
end;
/
```

![p4](https://i.imgur.com/U3oRByX.png)

##  Modificar el procedimiento anterior para que haga lo mismo pero devolviendo el número de usuarios que tienen ese tablespace como tablespace por defecto. Nota: Hay que convertir el procedimiento en función

```sql
CREATE OR REPLACE function f_numusuarios (p_tablespace dba_users.default_tablespace%type)
return number
is
    v_num number;
begin
    select count(username) into v_num from dba_users where default_tablespace=p_tablespace;
    return v_num;
end;
/
```

##  Hacer un procedimiento llamado mostrar_usuarios_por_tablespace que muestre por pantalla un listado de los tablespaces existentes con la lista de usuarios de cada uno y el número de los mismos, así: (Vistas DBA_TABLESPACES y DBA_USERS)

```sql
Tablespace xxxx:

	Usr1
	Usr2
	...

Total Usuarios Tablespace xxxx: n1

Tablespace yyyy:

	Usr1
	Usr2
	...

Total Usuarios Tablespace yyyy: n2
....
Total Usuarios BD: nn
```

He modificado el procedimiento del ejercicio 4:

```sql
CREATE OR REPLACE PROCEDURE verusuarios (p_tablespace dba_users.default_tablespace%type)
is
    cursor c_usuarios is
        SELECT username
        from dba_users
        where default_tablespace=p_tablespace;
begin
    for v_usuario in c_usuarios loop
        dbms_output.put_line(CHR(9)|| v_usuario.username);
    end loop;
end;
/
```

Y el procedimiento nuevo es:

```sql
CREATE OR REPLACE PROCEDURE mostrar_usuarios_por_tablespace
is
    cursor c_tablespaces is
        SELECT tablespace_name
        from dba_tablespaces;
    v_total_usuario number;
    v_total number:=0;
begin
    for v_tablespace in c_tablespaces loop
        dbms_output.put_line('Tablespace ' || v_tablespace.tablespace_name);
        verusuarios(v_tablespace.tablespace_name);
        v_total_usuario:=f_numusuarios(v_tablespace.tablespace_name);
        v_total:=v_total+v_total_usuario;
        dbms_output.put_line('Total Usuarios tablespace ' || v_tablespace.tablespace_name || ': ' || v_total_usuario);
    end loop;
    dbms_output.put_line('Total Usuarios BD : ' || v_total);
end;
/
```

![p5](https://i.imgur.com/1sCHBpU.png)

[...]

![p6](https://i.imgur.com/pbjFtsP.png)

##  Hacer un procedimiento llamado mostrar_codigo_fuente  que reciba el nombre de otro procedimiento y muestre su código fuente. (DBA_SOURCE)

```sql
CREATE OR REPLACE PROCEDURE mostrar_codigo_fuente (p_nombre dba_source.name%type)
is
    cursor c_codigo is
        SELECT text
        from dba_source
        where name=p_nombre;
begin
    for v_codigo in c_codigo loop
        dbms_output.put_line(v_codigo.text);
    end loop;
end;
/
```

![p7](https://i.imgur.com/zx9BQyp.png)

##  Hacer un procedimiento llamado mostrar_privilegios_usuario que reciba el nombre de un usuario y muestre sus privilegios de sistema y sus privilegios sobre objetos. (DBA_SYS_PRIVS y DBA_TAB_PRIVS)

```sql
CREATE OR REPLACE PROCEDURE mostrar_privilegios_usuario (p_nombre dba_source.name%type)
is
    cursor c_sistema is
        SELECT privilege
        from dba_sys_privs
        where grantee=p_nombre
        and ADMIN_OPTION='YES'
        OR INHERITED='YES';
    cursor c_objetos is
        SELECT privilege,table_name
        from dba_tab_privs
        where grantee=p_nombre;
begin
    dbms_output.put_line('Privilegios del usuario '|| p_nombre || ' de sistema');
    for v_sistema in c_sistema loop
        dbms_output.put_line(CHR(9)||v_sistema.privilege);
    end loop;
    dbms_output.put_line('Privilegios del usuario '|| p_nombre || ' sobre objetos');
    for v_objeto in c_objetos loop
        dbms_output.put_line(CHR(9)||v_objeto.privilege || '---' || v_objeto.table_name);
    end loop;
end;
/
```

![p8](https://i.imgur.com/V9bkArM.png)

##  Realiza un procedimiento llamado listar_comisiones que nos muestre por pantalla un listado de las comisiones de los empleados agrupados según la localidad donde está ubicado su departamento con el siguiente formato:

```sql
Localidad NombreLocalidad

    Departamento: NombreDepartamento

        Empleado1 ……. Comisión 1
        Empleado2 ……. Comisión 2
        .
        .
        .
        Empleadon ……. Comision n

    Total Comisiones en el Departamento NombreDepartamento: SumaComisiones

    Departamento: NombreDepartamento

        Empleado1 ……. Comisión 1
        Empleado2 ……. Comisión 2
        .
        .
        .
        Empleadon ……. Comision n

    Total Comisiones en el Departamento NombreDepartamento: SumaComisiones
    .
    .
Total Comisiones en la Localidad NombreLocalidad: SumaComisionesLocalidad

Localidad NombreLocalidad
.
.

Total Comisiones en la Empresa: TotalComisiones
```

Nota: Los nombres de localidades, departamentos y empleados deben aparecer por orden alfabético.

Si alguno de los departamentos no tiene ningún empleado con comisiones, aparecerá un mensaje informando de ello en lugar de la lista de empleados.

El procedimiento debe gestionar adecuadamente las siguientes excepciones:

    a) La tabla Empleados está vacía.
    b) Alguna comisión es mayor que 10000.

He creado dos funciones y un procedimiento:

```sql
CREATE OR REPLACE FUNCTION listar_empleados(p_deptno dept.deptno%type)
return number
is
    cursor c_empleados is
        SELECT ename,comm
        from emp
        where deptno=p_deptno
        order by ename;
    v_vacio number;
    v_suma number:=0;
    v_valor number;
begin
    select sum(comm) into v_vacio from emp where deptno=p_deptno;
    if v_vacio>0 then
        for v_empleado in c_empleados loop
            IF v_empleado.comm is NULL THEN
                v_valor:=0;
            ELSE
                v_suma:=v_suma+v_empleado.comm;
                v_valor:=v_empleado.comm;
            END IF;
            dbms_output.put_line(CHR(9)||CHR(9)|| v_empleado.ename || ' ... ' || v_valor);
        end loop;
    else
        dbms_output.put_line(CHR(9)||CHR(9)|| 'El departamento no tiene comisiones');
    end if;
    return v_suma;
EXCEPTION
    WHEN NO_DATA_FOUND then
        dbms_output.put_line('La tabla empleados está vacía');
        return 0;
end;
/

CREATE OR REPLACE FUNCTION listar_departamentos(p_loc dept.loc%type)
return number
is
    cursor c_departamentos is
        SELECT dname,deptno
        from dept
        where loc=p_loc
        order by dname;
    v_total number;
    v_suma number:=0;
begin
    for v_departamento in c_departamentos loop
        dbms_output.put_line(CHR(9)|| 'Departamento: ' || v_departamento.dname);
        v_total:=listar_empleados(v_departamento.deptno);
        dbms_output.put_line(CHR(9)|| 'Total Comisiones en el Departamento ' || v_departamento.dname || ': ' || v_total);
        v_suma:=v_suma+v_total;
    end loop;
    return v_suma;
end;
/

CREATE OR REPLACE PROCEDURE listar_comisiones
is
    cursor c_localidades is
        SELECT loc
        from dept
        order by loc;
    v_total number;
    v_suma number:=0;
begin
    for v_localidad in c_localidades loop
        dbms_output.put_line('Localidad ' || v_localidad.loc);
        v_total:=listar_departamentos(v_localidad.loc);
        dbms_output.put_line('Total Comisiones en la Localidad ' || v_localidad.loc || ': ' || v_total);
        v_suma:=v_suma+v_total;
    end loop;
    dbms_output.put_line('Total Comisiones de la Empresa ' || v_suma);
end;
/
```

![p9](https://i.imgur.com/DGWQS1b.png)

## . Realiza un procedimiento que reciba el nombre de una tabla y muestre los nombres de las restricciones que tiene, a qué columna afectan y en qué consisten exactamente. (DBA_TABLES, DBA_CONSTRAINTS, DBA_CONS_COLUMNS)

He realizado los siguientes procedimientos:

```sql
CREATE OR REPLACE PROCEDURE listar_restriccion(p_nombre user_constraints.table_name%type,p_tabla user_constraints.table_name%type)
is
    v_tipo user_constraints.constraint_type%type;
    v_nombre user_constraints.constraint_name%type;
    v_referencia user_constraints.r_constraint_name%type;
    v_condicion user_constraints.search_condition%type;
begin
    select constraint_name,constraint_type,r_constraint_name,search_condition into v_nombre,v_tipo,v_referencia,v_condicion
    from user_constraints
    where table_name = p_tabla
    and constraint_name=p_nombre;
    if v_tipo='P' then
        dbms_output.put_line(p_nombre || ' ... es de tipo CLAVE PRIMARIA');
    elsif v_tipo='R' then
        dbms_output.put_line(p_nombre || ' ... es de tipo CLAVE EXTERNA y hace referencia a: ' || v_nombre);
    elsif v_tipo='C' then
        dbms_output.put_line(p_nombre || ' ... es de tipo CHECK y contiene la siguiente comprobacion: ' || v_condicion); 
    end if;
end;
/

CREATE OR REPLACE PROCEDURE listar_restricciones(p_tabla user_constraints.table_name%type)
is
    cursor c_columnas is
        SELECT constraint_name,column_name
        from user_cons_columns
        where table_name=p_tabla;
begin
    dbms_output.put_line('Restricciones de la tabla ' || p_tabla);
    for v_columna in c_columnas loop
        listar_restriccion(v_columna.constraint_name,p_tabla);
        dbms_output.put_line(CHR(9)||'Hace referencia a la columna -> ' || v_columna.column_name);
    end loop;
end;
/
```

En la comprobación introduzco una tabla diferente al esquema SCOTT ya que tiene más restricciones:

![p10](https://i.imgur.com/OMoSRQz.png)

##  Realiza al menos dos de los ejercicios anteriores en Postgres usando PL/pgSQL.

## Ejercicio 1

```sql
CREATE or replace PROCEDURE mostrarnombresalario() AS $$
DECLARE
    v_nombre emp.ename%type;
    v_salario emp.sal%type;
BEGIN
    select ename,sal into v_nombre,v_salario from emp where empno=7782;
    RAISE NOTICE 'El nombre del empleado es %, y su salario es %', v_nombre,v_salario;
END;
$$ LANGUAGE plpgsql;
```

![p11](https://i.imgur.com/GifaOGt.png)

## Ejercicio 2

```sql
CREATE or replace PROCEDURE mostrarnombresalario2(p_empno emp.empno%type) AS $$
DECLARE
    v_nombre emp.ename%type;
BEGIN
    select ename into v_nombre from emp where empno=7782;
    RAISE NOTICE 'El nombre del empleado cuyo codigo es %, es %', p_empno,v_nombre;
END;
$$ LANGUAGE plpgsql;
```

![p12](https://i.imgur.com/OKfLC2X.png)