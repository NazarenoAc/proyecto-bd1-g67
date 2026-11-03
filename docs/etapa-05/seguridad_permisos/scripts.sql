-- Seguridad y permisos - Sonora Instrumentos
-- Usa sp_InsertarCliente del script de procedimientos y funciones

-- Modo de autenticación del servidor
SELECT CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
            WHEN 0 THEN 'Modo mixto (Windows y SQL Server)'
            ELSE 'Solo Windows' END AS modo_autenticacion;
GO

-- Logins del servidor
USE master;
GO
IF SUSER_ID('login_admin') IS NULL
    CREATE LOGIN login_admin WITH PASSWORD = 'Admin#2026Sonora', CHECK_POLICY = OFF;
IF SUSER_ID('login_lectura') IS NULL
    CREATE LOGIN login_lectura WITH PASSWORD = 'Lectura#2026Sonora', CHECK_POLICY = OFF;
IF SUSER_ID('login_vendedor') IS NULL
    CREATE LOGIN login_vendedor WITH PASSWORD = 'Vendedor#2026Sonora', CHECK_POLICY = OFF;
IF SUSER_ID('login_tecnico') IS NULL
    CREATE LOGIN login_tecnico WITH PASSWORD = 'Tecnico#2026Sonora', CHECK_POLICY = OFF;
GO

-- Usuarios de la base
USE SonoraInstrumentos;
GO
IF DATABASE_PRINCIPAL_ID('usr_admin') IS NULL    CREATE USER usr_admin    FOR LOGIN login_admin;
IF DATABASE_PRINCIPAL_ID('usr_lectura') IS NULL  CREATE USER usr_lectura  FOR LOGIN login_lectura;
IF DATABASE_PRINCIPAL_ID('usr_vendedor') IS NULL CREATE USER usr_vendedor FOR LOGIN login_vendedor;
IF DATABASE_PRINCIPAL_ID('usr_tecnico') IS NULL  CREATE USER usr_tecnico  FOR LOGIN login_tecnico;

-- Permisos por usuario: uno administrador y otro de solo lectura que puede ejecutar el procedimiento
ALTER ROLE db_owner ADD MEMBER usr_admin;
ALTER ROLE db_datareader ADD MEMBER usr_lectura;
GRANT EXECUTE ON dbo.sp_InsertarCliente TO usr_lectura;

-- Permisos por rol: solo lectura del catálogo, asignado al vendedor
IF DATABASE_PRINCIPAL_ID('rol_lectura_catalogo') IS NULL
    CREATE ROLE rol_lectura_catalogo;
GRANT SELECT ON dbo.Instrumento TO rol_lectura_catalogo;
GRANT SELECT ON dbo.Categoria   TO rol_lectura_catalogo;
GRANT SELECT ON dbo.Marca       TO rol_lectura_catalogo;
ALTER ROLE rol_lectura_catalogo ADD MEMBER usr_vendedor;
GO

-- Borra los clientes de prueba y prepara la tabla de resultados
DELETE FROM Cliente WHERE dni BETWEEN 47000001 AND 47000009;

DROP TABLE IF EXISTS #resultados;
CREATE TABLE #resultados (
    usuario   VARCHAR(30),
    operacion VARCHAR(60),
    resultado VARCHAR(10),
    mensaje   NVARCHAR(400)
);
GO


-- Insert directo con el administrador
DECLARE @error NVARCHAR(400);
EXECUTE AS USER = 'usr_admin';
BEGIN TRY
    INSERT INTO Cliente (dni, nombre, apellido, num_telefono)
    VALUES (47000001, 'Prueba', 'Admin', '3794000001');
END TRY
BEGIN CATCH
    SET @error = ERROR_MESSAGE();
END CATCH;
REVERT;
INSERT INTO #resultados VALUES ('usr_admin', 'INSERT directo en Cliente',
       IIF(@error IS NULL, 'PERMITIDO', 'DENEGADO'), @error);
GO

-- Insert directo con el usuario de solo lectura
DECLARE @error NVARCHAR(400);
EXECUTE AS USER = 'usr_lectura';
BEGIN TRY
    INSERT INTO Cliente (dni, nombre, apellido, num_telefono)
    VALUES (47000002, 'Prueba', 'Lectura', '3794000002');
END TRY
BEGIN CATCH
    SET @error = ERROR_MESSAGE();
END CATCH;
REVERT;
INSERT INTO #resultados VALUES ('usr_lectura', 'INSERT directo en Cliente',
       IIF(@error IS NULL, 'PERMITIDO', 'DENEGADO'), @error);
GO

-- Insert con el procedimiento usando el usuario de solo lectura
DECLARE @error NVARCHAR(400);
EXECUTE AS USER = 'usr_lectura';
BEGIN TRY
    EXEC dbo.sp_InsertarCliente 47000003, 'Prueba', 'Procedimiento', '3794000003';
END TRY
BEGIN CATCH
    SET @error = ERROR_MESSAGE();
END CATCH;
REVERT;
INSERT INTO #resultados VALUES ('usr_lectura', 'EXEC sp_InsertarCliente',
       IIF(@error IS NULL, 'PERMITIDO', 'DENEGADO'), @error);
GO

-- Lectura de Instrumento con el vendedor (tiene el rol)
DECLARE @error NVARCHAR(400), @filas INT;
EXECUTE AS USER = 'usr_vendedor';
BEGIN TRY
    SELECT @filas = COUNT(*) FROM Instrumento;
END TRY
BEGIN CATCH
    SET @error = ERROR_MESSAGE();
END CATCH;
REVERT;
INSERT INTO #resultados VALUES ('usr_vendedor', 'SELECT de Instrumento',
       IIF(@error IS NULL, 'PERMITIDO', 'DENEGADO'), ISNULL(@error, CONCAT('Leyó ', @filas, ' filas')));
GO

-- Lectura de Instrumento con el técnico (no tiene el rol)
DECLARE @error NVARCHAR(400), @filas INT;
EXECUTE AS USER = 'usr_tecnico';
BEGIN TRY
    SELECT @filas = COUNT(*) FROM Instrumento;
END TRY
BEGIN CATCH
    SET @error = ERROR_MESSAGE();
END CATCH;
REVERT;
INSERT INTO #resultados VALUES ('usr_tecnico', 'SELECT de Instrumento',
       IIF(@error IS NULL, 'PERMITIDO', 'DENEGADO'), ISNULL(@error, CONCAT('Leyó ', @filas, ' filas')));
GO


-- Resultados de las pruebas
SELECT usuario, operacion, resultado, mensaje FROM #resultados;

-- Clientes que quedaron (el 47000002 se rechazó)
SELECT id_cliente, dni, nombre, apellido
FROM Cliente WHERE dni BETWEEN 47000001 AND 47000009;

-- Roles y permisos de cada usuario
SELECT m.name AS usuario, r.name AS rol
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE m.name IN ('usr_admin', 'usr_lectura', 'usr_vendedor', 'usr_tecnico');

SELECT pr.name AS usuario_o_rol, pe.permission_name AS permiso, OBJECT_NAME(pe.major_id) AS objeto
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name IN ('usr_lectura', 'rol_lectura_catalogo') AND pe.class = 1;
GO
