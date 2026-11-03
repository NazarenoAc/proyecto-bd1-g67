-- Manejo de transacciones y transacciones anidadas - Sonora Instrumentos
-- Usa sp_RegistrarVenta del script de procedimientos y funciones

USE SonoraInstrumentos;
GO


-- Estado antes de las pruebas
SELECT (SELECT COUNT(*) FROM Venta)        AS ventas,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles,
       (SELECT stock FROM Instrumento WHERE cod_instrumento = 4) AS stock_teclado;
GO


-- Venta completa dentro de una transacción
DECLARE @id_venta INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO Venta (id_cliente, dni_vendedor, id_metodo_pago)
    VALUES (4, 30000004, 2);

    SET @id_venta = SCOPE_IDENTITY();

    INSERT INTO DetalleVenta (id_venta, cod_instrumento, cantidad, precio_unitario)
    SELECT @id_venta, cod_instrumento, 1, precio
    FROM Instrumento WHERE cod_instrumento = 4;

    UPDATE Instrumento SET stock = stock - 1 WHERE cod_instrumento = 4;

    COMMIT TRANSACTION;
    SELECT 'Venta confirmada' AS resultado, @id_venta AS id_venta;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'Se deshizo la transacción' AS resultado, ERROR_MESSAGE() AS error;
END CATCH;

SELECT (SELECT COUNT(*) FROM Venta)        AS ventas,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles,
       (SELECT stock FROM Instrumento WHERE cod_instrumento = 4) AS stock_teclado;
GO


-- Error provocado después del insert
DECLARE @id_venta INT;

SELECT (SELECT COUNT(*) FROM Venta)        AS ventas_antes,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles_antes,
       (SELECT stock FROM Instrumento WHERE cod_instrumento = 4) AS stock_antes;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO Venta (id_cliente, dni_vendedor, id_metodo_pago)
    VALUES (4, 30000004, 2);

    SET @id_venta = SCOPE_IDENTITY();
    SELECT 'Venta insertada, todavía sin confirmar' AS estado, @id_venta AS id_venta;

    THROW 50010, 'Error provocado después de insertar la venta.', 1;

    INSERT INTO DetalleVenta (id_venta, cod_instrumento, cantidad, precio_unitario)
    SELECT @id_venta, cod_instrumento, 1, precio
    FROM Instrumento WHERE cod_instrumento = 4;

    UPDATE Instrumento SET stock = stock - 1 WHERE cod_instrumento = 4;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'Se deshizo la transacción' AS resultado, ERROR_MESSAGE() AS error;
END CATCH;

-- Totales después del error
SELECT (SELECT COUNT(*) FROM Venta)        AS ventas_despues,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles_despues,
       (SELECT stock FROM Instrumento WHERE cod_instrumento = 4) AS stock_despues,
       (SELECT COUNT(*) FROM Venta WHERE id_venta = @id_venta) AS existe_venta_insertada;
GO


-- Venta con el procedimiento dentro de una transacción
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_RegistrarVenta 5, 30000005, 1, 4, 1;
    COMMIT TRANSACTION;
    SELECT 'Venta confirmada' AS resultado;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'Se deshizo la transacción' AS resultado, ERROR_MESSAGE() AS error;
END CATCH;
GO

-- Error: no hay stock suficiente
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_RegistrarVenta 5, 30000005, 1, 4, 100;
    COMMIT TRANSACTION;
    SELECT 'Venta confirmada' AS resultado;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'Se deshizo la transacción' AS resultado, ERROR_MESSAGE() AS error;
END CATCH;

SELECT (SELECT COUNT(*) FROM Venta)        AS ventas,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles,
       (SELECT stock FROM Instrumento WHERE cod_instrumento = 4) AS stock_teclado;
GO


-- Transacción anidada
SELECT (SELECT COUNT(*) FROM Venta)        AS ventas_antes,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles_antes;

DECLARE @id_venta INT;

BEGIN TRANSACTION;
SELECT 'Externa abierta' AS estado, @@TRANCOUNT AS trancount;

INSERT INTO Venta (id_cliente, dni_vendedor, id_metodo_pago)
VALUES (6, 30000006, 3);
SET @id_venta = SCOPE_IDENTITY();

    BEGIN TRANSACTION;
    SELECT 'Interna abierta' AS estado, @@TRANCOUNT AS trancount;

    INSERT INTO DetalleVenta (id_venta, cod_instrumento, cantidad, precio_unitario)
    SELECT @id_venta, cod_instrumento, 1, precio
    FROM Instrumento WHERE cod_instrumento = 4;

    COMMIT TRANSACTION;
    SELECT 'Interna confirmada' AS estado, @@TRANCOUNT AS trancount;

ROLLBACK TRANSACTION;
SELECT 'Externa deshecha' AS estado, @@TRANCOUNT AS trancount;

SELECT (SELECT COUNT(*) FROM Venta)        AS ventas_despues,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles_despues;
GO


-- Venta de dos instrumentos con punto de guardado
DECLARE @id_venta INT;

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO Venta (id_cliente, dni_vendedor, id_metodo_pago)
    VALUES (6, 30000006, 3);
    SET @id_venta = SCOPE_IDENTITY();

    -- Primer ítem: teclado
    INSERT INTO DetalleVenta (id_venta, cod_instrumento, cantidad, precio_unitario)
    SELECT @id_venta, cod_instrumento, 1, precio
    FROM Instrumento WHERE cod_instrumento = 4;
    UPDATE Instrumento SET stock = stock - 1 WHERE cod_instrumento = 4;

    SAVE TRANSACTION segundo_item;

    -- Segundo ítem: saxo
    BEGIN TRY
        INSERT INTO DetalleVenta (id_venta, cod_instrumento, cantidad, precio_unitario)
        SELECT @id_venta, cod_instrumento, 1, precio
        FROM Instrumento WHERE cod_instrumento = 7;
        UPDATE Instrumento SET stock = stock - 1 WHERE cod_instrumento = 7;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION segundo_item;
        SELECT 'Se descartó el saxo' AS estado, ERROR_MESSAGE() AS error;
    END CATCH;

    COMMIT TRANSACTION;
    SELECT 'Venta confirmada' AS resultado, @id_venta AS id_venta;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'Se deshizo la transacción' AS resultado, ERROR_MESSAGE() AS error;
END CATCH;

-- Detalle de la venta y stock
SELECT dv.id_venta, i.nombre_instrumento, dv.cantidad, dv.precio_unitario
FROM DetalleVenta dv
JOIN Instrumento i ON i.cod_instrumento = dv.cod_instrumento
WHERE dv.id_venta = @id_venta;

SELECT cod_instrumento, nombre_instrumento, stock
FROM Instrumento WHERE cod_instrumento IN (4, 7);
GO


-- Procedimiento que registra la venta dentro de una transacción
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarVentaTransaccional
    @id_cliente      INT,
    @dni_vendedor    INT,
    @id_metodo_pago  INT,
    @cod_instrumento INT,
    @cantidad        INT,
    @forzar_error    BIT = 0,
    @id_venta        INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Cabecera de la venta
        INSERT INTO Venta (id_cliente, dni_vendedor, id_metodo_pago)
        VALUES (@id_cliente, @dni_vendedor, @id_metodo_pago);

        SET @id_venta = SCOPE_IDENTITY();

        -- Error provocado a propósito
        IF @forzar_error = 1
            THROW 50011, 'Error provocado después del insert en Venta.', 1;

        -- Detalle de la venta
        INSERT INTO DetalleVenta (id_venta, cod_instrumento, cantidad, precio_unitario)
        SELECT @id_venta, cod_instrumento, @cantidad, precio
        FROM Instrumento
        WHERE cod_instrumento = @cod_instrumento;

        IF @@ROWCOUNT = 0
            THROW 50012, 'El instrumento no existe.', 1;

        -- Descuenta el stock
        UPDATE Instrumento
        SET stock = stock - @cantidad
        WHERE cod_instrumento = @cod_instrumento;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO

-- Venta de una guitarra RG con el procedimiento
DECLARE @id_venta INT;

SELECT (SELECT COUNT(*) FROM Venta)        AS ventas_antes,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles_antes,
       (SELECT stock FROM Instrumento WHERE cod_instrumento = 9) AS stock_rg_antes;

EXEC dbo.sp_RegistrarVentaTransaccional 7, 30000007, 4, 9, 1, @id_venta = @id_venta OUTPUT;

SELECT 'Venta confirmada' AS resultado, @id_venta AS id_venta;

SELECT (SELECT COUNT(*) FROM Venta)        AS ventas_despues,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles_despues,
       (SELECT stock FROM Instrumento WHERE cod_instrumento = 9) AS stock_rg_despues;
GO

-- Error provocado después del insert
SELECT (SELECT COUNT(*) FROM Venta)        AS ventas_antes,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles_antes,
       (SELECT stock FROM Instrumento WHERE cod_instrumento = 9) AS stock_rg_antes;

BEGIN TRY
    EXEC dbo.sp_RegistrarVentaTransaccional 7, 30000007, 4, 9, 1, @forzar_error = 1;
END TRY
BEGIN CATCH
    SELECT 'Se deshizo la transacción' AS resultado, ERROR_MESSAGE() AS error;
END CATCH;

SELECT (SELECT COUNT(*) FROM Venta)        AS ventas_despues,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles_despues,
       (SELECT stock FROM Instrumento WHERE cod_instrumento = 9) AS stock_rg_despues;
GO

-- Error: no hay stock suficiente
BEGIN TRY
    EXEC dbo.sp_RegistrarVentaTransaccional 7, 30000007, 4, 9, 100;
END TRY
BEGIN CATCH
    SELECT 'Se deshizo la transacción' AS resultado, ERROR_MESSAGE() AS error;
END CATCH;

SELECT (SELECT COUNT(*) FROM Venta)        AS ventas_despues,
       (SELECT COUNT(*) FROM DetalleVenta) AS detalles_despues,
       (SELECT stock FROM Instrumento WHERE cod_instrumento = 9) AS stock_rg_despues;
GO
