# Manejo de permisos a nivel de usuarios de base de datos

Script: [`scripts.sql`](scripts.sql). Capturas: carpeta [`evidencias/`](evidencias/).

## 1. Definición y objetivo

La seguridad en SQL Server se maneja en dos niveles:

- **Login:** la cuenta que permite conectarse al **servidor**. Puede ser de Windows o de SQL Server (usuario y contraseña).
- **Usuario:** la cuenta dentro de una **base de datos**, asociada a un login. Sobre el usuario se dan los permisos.

Un **permiso** autoriza una acción sobre un objeto: `SELECT` (leer), `INSERT`, `UPDATE`, `DELETE` (escribir) o `EXECUTE` (ejecutar un procedimiento). Un **rol** agrupa permisos: todos los miembros del rol reciben lo que tiene el rol.

El objetivo es que cada persona que usa la base de Sonora Instrumentos pueda hacer solo lo que necesita (principio de **mínimo privilegio**).

## 2. Ventajas y aplicaciones

- Protegen los datos de cambios no autorizados.
- Con roles, los permisos se administran una sola vez para un grupo de usuarios.
- Combinados con procedimientos, permiten que un usuario modifique datos solo de la forma controlada por el procedimiento.

Se aplican para separar administradores, empleados que cargan datos y usuarios que solo consultan.

## 3. Implementación en SQL Server

- **Modo de autenticación:** para usar logins de SQL Server, el servidor tiene que estar en **modo mixto** (Windows y SQL Server). Se verifica con `SERVERPROPERTY('IsIntegratedSecurityOnly')`: 0 es mixto y 1 es solo Windows. Se cambia en SSMS, desde *Propiedades del servidor* → *Seguridad*, y después hay que reiniciar el servicio.
- `CREATE LOGIN ... WITH PASSWORD` crea el login y `CREATE USER ... FOR LOGIN` crea su usuario en la base.
- `ALTER ROLE rol ADD MEMBER usuario` agrega el usuario a un rol. `db_owner` (administrador) y `db_datareader` (lectura de todas las tablas) vienen con SQL Server.
- `CREATE ROLE` crea un rol propio, y `GRANT permiso ON objeto TO usuario_o_rol` le da un permiso.
- `EXECUTE AS USER = '...'` ... `REVERT` permite probar los permisos como si fuera ese usuario.

## 4. Caso concreto en Sonora Instrumentos

**Permisos a nivel de usuario:**

| Usuario | Login | Permisos |
|---|---|---|
| `usr_admin` | `login_admin` | `db_owner`: administrador de la base |
| `usr_lectura` | `login_lectura` | `db_datareader`: solo lectura, más `EXECUTE` sobre `sp_InsertarCliente` (tema de procedimientos) |

**Permisos a nivel de rol:**

| Usuario | Login | Rol |
|---|---|---|
| `usr_vendedor` | `login_vendedor` | `rol_lectura_catalogo`: `SELECT` sobre `Instrumento`, `Categoria` y `Marca` |
| `usr_tecnico` | `login_tecnico` | ninguno |

El vendedor necesita consultar el catálogo para atender ventas; el técnico trabaja con los instrumentos de los clientes y no necesita el catálogo de la empresa.

## 5. Script de demostración y resultados

**Modo de autenticación** (captura `01-modo-mixto.png`): la consulta tiene que devolver "Modo mixto (Windows y SQL Server)".

**Resultados de las pruebas** (captura `02-resultados.png`). Todas se hacen con `EXECUTE AS USER` y se juntan en una tabla:

| Usuario | Operación | Resultado |
|---|---|---|
| `usr_admin` | INSERT directo en `Cliente` | PERMITIDO |
| `usr_lectura` | INSERT directo en `Cliente` | DENEGADO: *The INSERT permission was denied on the object 'Cliente'* |
| `usr_lectura` | `EXEC sp_InsertarCliente` | PERMITIDO |
| `usr_vendedor` | SELECT de `Instrumento` | PERMITIDO (10 filas) |
| `usr_tecnico` | SELECT de `Instrumento` | DENEGADO: *The SELECT permission was denied on the object 'Instrumento'* |

En `Cliente` quedan los DNI 47000001 (insertado por el admin) y 47000003 (insertado por el de lectura con el procedimiento). El 47000002 no está porque se rechazó.

**Roles y permisos asignados** (captura `03-roles-y-permisos.png`): las consultas a `sys.database_role_members` y `sys.database_permissions` muestran cada usuario con su rol, el `EXECUTE` de `usr_lectura` y los tres `SELECT` de `rol_lectura_catalogo`.

**Prueba con el login real** (captura `04-login-lectura.png`). Requiere el modo mixto activado:

1. En SSMS: *Conectar* → *Motor de base de datos*, con autenticación **SQL Server**, usuario `login_lectura` y contraseña `Lectura#2026Sonora`.
2. En una consulta nueva:

```sql
USE SonoraInstrumentos;
INSERT INTO Cliente (dni, nombre, apellido, num_telefono)
VALUES (47000004, 'Prueba', 'Login', '3794000004');
EXEC dbo.sp_InsertarCliente 47000005, 'Prueba', 'Login', '3794000005';
```

El `INSERT` directo da el error de permiso denegado y el `EXEC` inserta el cliente.

## Conclusiones

- Para usar usuarios de SQL Server con su propia contraseña, el servidor tiene que estar en modo mixto.
- Con solo lectura, el `INSERT` directo se rechaza, pero el `INSERT` a través del procedimiento funciona. Esto pasa por el **encadenamiento de propiedad**: el procedimiento y la tabla tienen el mismo dueño (`dbo`), así que SQL Server solo verifica el permiso `EXECUTE` y no el `INSERT` sobre la tabla. Así se puede dejar que un usuario cargue clientes solo con las validaciones del procedimiento.
- Un `GRANT` al rol alcanza a todos sus miembros: el vendedor puede leer el catálogo porque está en el rol, y el técnico, que no está, no puede.
- Leer, escribir y ejecutar son permisos separados, lo que permite dar a cada usuario solo lo que necesita.
