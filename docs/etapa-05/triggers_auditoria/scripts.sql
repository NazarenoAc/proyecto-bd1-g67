-- Triggers de auditoría - Sonora Instrumentos
-- Las pruebas que modifican datos van dentro de una transacción y terminan con ROLLBACK,
-- así el script se puede correr varias veces sin alterar stock, precios ni clientes de los otros temas.
-- Para ver solo lo que genera cada prueba, cada lote guarda el último id de auditoría (@desde).

USE SonoraInstrumentos;
GO


-- TABLAS DE AUDITORÍA

IF OBJECT_ID('dbo.AuditoriaInstrumento', 'U') IS NULL
CREATE TABLE dbo.AuditoriaInstrumento (
    id_auditoria           INT IDENTITY(1,1)
        CONSTRAINT PK_AuditoriaInstrumento PRIMARY KEY,
    operacion              VARCHAR(6)    NOT NULL
        CONSTRAINT CK_AudInstrumento_operacion CHECK (operacion IN ('UPDATE','DELETE')),
    fecha_hora             DATETIME      NOT NULL
        CONSTRAINT DF_AudInstrumento_fecha DEFAULT GETDATE(),
    usuario_bd             SYSNAME       NOT NULL
        CONSTRAINT DF_AudInstrumento_usuario DEFAULT USER_NAME(),
    login_servidor         SYSNAME       NOT NULL
        CONSTRAINT DF_AudInstrumento_login DEFAULT SUSER_SNAME(),

    cod_instrumento        INT           NOT NULL,
    nombre_instrumento_ant VARCHAR(100)  NOT NULL,
    precio_ant             DECIMAL(12,2) NOT NULL,
    stock_ant              INT           NOT NULL,
    id_categoria_ant       INT           NOT NULL,
    id_marca_ant           INT           NOT NULL
);
GO

IF OBJECT_ID('dbo.AuditoriaCliente', 'U') IS NULL
CREATE TABLE dbo.AuditoriaCliente (
    id_auditoria      INT IDENTITY(1,1)
        CONSTRAINT PK_AuditoriaCliente PRIMARY KEY,
    operacion         VARCHAR(6)  NOT NULL
        CONSTRAINT CK_AudCliente_operacion CHECK (operacion IN ('UPDATE','DELETE')),
    fecha_hora        DATETIME    NOT NULL
        CONSTRAINT DF_AudCliente_fecha DEFAULT GETDATE(),
    usuario_bd        SYSNAME     NOT NULL
        CONSTRAINT DF_AudCliente_usuario DEFAULT USER_NAME(),
    login_servidor    SYSNAME     NOT NULL
        CONSTRAINT DF_AudCliente_login DEFAULT SUSER_SNAME(),

    id_cliente        INT         NOT NULL,
    dni_ant           INT         NOT NULL,
    nombre_ant        VARCHAR(50) NOT NULL,
    apellido_ant      VARCHAR(50) NOT NULL,
    num_telefono_ant  VARCHAR(20) NOT NULL
);
GO


-- TRIGGERS

-- Guarda los valores anteriores del instrumento cuando se modifica
CREATE OR ALTER TRIGGER dbo.trg_Instrumento_AuditUpdate
ON dbo.Instrumento
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditoriaInstrumento
        (operacion, cod_instrumento, nombre_instrumento_ant, precio_ant,
         stock_ant, id_categoria_ant, id_marca_ant)
    SELECT 'UPDATE', d.cod_instrumento, d.nombre_instrumento, d.precio,
           d.stock, d.id_categoria, d.id_marca
    FROM deleted AS d;
END;
GO

-- Guarda el instrumento borrado
CREATE OR ALTER TRIGGER dbo.trg_Instrumento_AuditDelete
ON dbo.Instrumento
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditoriaInstrumento
        (operacion, cod_instrumento, nombre_instrumento_ant, precio_ant,
         stock_ant, id_categoria_ant, id_marca_ant)
    SELECT 'DELETE', d.cod_instrumento, d.nombre_instrumento, d.precio,
           d.stock, d.id_categoria, d.id_marca
    FROM deleted AS d;
END;
GO

-- Guarda los valores anteriores del cliente cuando se modifica
CREATE OR ALTER TRIGGER dbo.trg_Cliente_AuditUpdate
ON dbo.Cliente
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditoriaCliente
        (operacion, id_cliente, dni_ant, nombre_ant, apellido_ant, num_telefono_ant)
    SELECT 'UPDATE', d.id_cliente, d.dni, d.nombre, d.apellido, d.num_telefono
    FROM deleted AS d;
END;
GO

-- Guarda el cliente borrado
CREATE OR ALTER TRIGGER dbo.trg_Cliente_AuditDelete
ON dbo.Cliente
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditoriaCliente
        (operacion, id_cliente, dni_ant, nombre_ant, apellido_ant, num_telefono_ant)
    SELECT 'DELETE', d.id_cliente, d.dni, d.nombre, d.apellido, d.num_telefono
    FROM deleted AS d;
END;
GO

-- Impide borrar ventas para conservar el historial comercial
-- (el código 50020 no se repite con los de los otros temas)
CREATE OR ALTER TRIGGER dbo.trg_Venta_BloquearDelete
ON dbo.Venta
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50020, N'Operación no permitida: las ventas no se pueden eliminar para preservar el historial comercial.', 1;
END;
GO
-- PRUEBAS

-- Prueba 1: cambio de precio de la Stratocaster (cod 1)
DECLARE @desde INT = ISNULL((SELECT MAX(id_auditoria) FROM AuditoriaInstrumento), 0);

BEGIN TRANSACTION;

SELECT cod_instrumento, nombre_instrumento, precio, stock
FROM Instrumento WHERE cod_instrumento = 1;

UPDATE Instrumento SET precio = 900000.00 WHERE cod_instrumento = 1;

-- Precio nuevo y fila de auditoría con el precio anterior
SELECT cod_instrumento, nombre_instrumento, precio, stock
FROM Instrumento WHERE cod_instrumento = 1;

SELECT * FROM AuditoriaInstrumento WHERE id_auditoria > @desde;

ROLLBACK TRANSACTION;

-- Después del ROLLBACK el precio vuelve al original y la auditoría también se deshace
SELECT precio AS precio_despues_del_rollback
FROM Instrumento WHERE cod_instrumento = 1;
GO


-- Prueba 2: un UPDATE que modifica varias filas (stock de la categoría 3)
DECLARE @desde INT = ISNULL((SELECT MAX(id_auditoria) FROM AuditoriaInstrumento), 0);

BEGIN TRANSACTION;

UPDATE Instrumento SET stock = stock + 1 WHERE id_categoria = 3;

-- Una fila de auditoría por instrumento
SELECT * FROM AuditoriaInstrumento
WHERE id_auditoria > @desde
ORDER BY cod_instrumento;

ROLLBACK TRANSACTION;
GO


-- Prueba 3: borrado de un instrumento sin ventas
DECLARE @desde INT = ISNULL((SELECT MAX(id_auditoria) FROM AuditoriaInstrumento), 0);
DECLARE @id INT;

BEGIN TRANSACTION;

-- Usa una categoría y una marca que ya existen
INSERT INTO Instrumento (nombre_instrumento, precio, stock, id_categoria, id_marca)
SELECT TOP 1 'Instrumento de prueba (auditoria)', 1000.00, 1, id_categoria, id_marca
FROM Instrumento
ORDER BY cod_instrumento;

SET @id = SCOPE_IDENTITY();

DELETE FROM Instrumento WHERE cod_instrumento = @id;

SELECT * FROM AuditoriaInstrumento
WHERE id_auditoria > @desde AND operacion = 'DELETE';

ROLLBACK TRANSACTION;
GO


-- Prueba 4: borrado de un instrumento con ventas (lo rechaza la FK)
DECLARE @desde INT = ISNULL((SELECT MAX(id_auditoria) FROM AuditoriaInstrumento), 0);

BEGIN TRANSACTION;

BEGIN TRY
    DELETE FROM Instrumento WHERE cod_instrumento = 1;
    SELECT 'Se borró el instrumento 1' AS resultado;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje;
END CATCH;

-- No debe haber fila de auditoría
SELECT COUNT(*) AS filas_delete_instrumento_1
FROM AuditoriaInstrumento
WHERE id_auditoria > @desde AND operacion = 'DELETE' AND cod_instrumento = 1;

IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO


-- Prueba 5: cambio de teléfono de un cliente
DECLARE @desde INT = ISNULL((SELECT MAX(id_auditoria) FROM AuditoriaCliente), 0);

BEGIN TRANSACTION;

UPDATE Cliente SET num_telefono = '3794000000' WHERE id_cliente = 1;

SELECT * FROM AuditoriaCliente WHERE id_auditoria > @desde;

ROLLBACK TRANSACTION;

SELECT id_cliente, num_telefono AS telefono_despues_del_rollback
FROM Cliente WHERE id_cliente = 1;
GO


-- Prueba 6: borrado de un cliente sin operaciones
DECLARE @desde INT = ISNULL((SELECT MAX(id_auditoria) FROM AuditoriaCliente), 0);
DECLARE @idc INT;

BEGIN TRANSACTION;

INSERT INTO Cliente (dni, nombre, apellido, num_telefono)
VALUES (99999999, 'Cliente', 'De Prueba', '3790000000');

SET @idc = SCOPE_IDENTITY();

DELETE FROM Cliente WHERE id_cliente = @idc;

SELECT * FROM AuditoriaCliente
WHERE id_auditoria > @desde AND operacion = 'DELETE';

ROLLBACK TRANSACTION;
GO


-- Prueba 7: intento de borrar una venta
DECLARE @ventas_antes INT = (SELECT COUNT(*) FROM Venta);
DECLARE @detalles_antes INT = (SELECT COUNT(*) FROM DetalleVenta);

BEGIN TRANSACTION;

BEGIN TRY
    DELETE FROM Venta WHERE id_venta = 1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT @ventas_antes   AS ventas_antes,   (SELECT COUNT(*) FROM Venta)        AS ventas_despues,
       @detalles_antes AS detalles_antes, (SELECT COUNT(*) FROM DetalleVenta) AS detalles_despues;

IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO


-- Prueba 8: intento de borrar todas las ventas
DECLARE @ventas_antes INT = (SELECT COUNT(*) FROM Venta);

BEGIN TRANSACTION;

BEGIN TRY
    DELETE FROM Venta;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS numero_error, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT @ventas_antes AS ventas_antes, (SELECT COUNT(*) FROM Venta) AS ventas_despues;

IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
GO


-- Prueba 9: la venta del tema de procedimientos también queda auditada
-- (necesita sp_RegistrarVenta; la venta se deshace al final)
DECLARE @desde INT = ISNULL((SELECT MAX(id_auditoria) FROM AuditoriaInstrumento), 0);

SELECT cod_instrumento, nombre_instrumento, stock AS stock_antes
FROM Instrumento WHERE cod_instrumento = 4;

BEGIN TRANSACTION;

EXEC dbo.sp_RegistrarVenta 5, 30000005, 1, 4, 1;

-- stock_ant es el stock que tenía el teclado antes de la venta
SELECT * FROM AuditoriaInstrumento WHERE id_auditoria > @desde;

ROLLBACK TRANSACTION;
GO


-- Consulta de auditoría: cambios confirmados en las dos tablas
-- (muestra, por ejemplo, el stock descontado por las ventas de los otros temas)
SELECT 'Instrumento' AS tabla, operacion, fecha_hora, usuario_bd, login_servidor,
       cod_instrumento AS id_registro
FROM AuditoriaInstrumento
UNION ALL
SELECT 'Cliente', operacion, fecha_hora, usuario_bd, login_servidor, id_cliente
FROM AuditoriaCliente
ORDER BY fecha_hora;
GO
