-- Procedimientos y funciones almacenadas - Sonora Instrumentos

USE SonoraInstrumentos;
GO

-- Borra los clientes de prueba para poder correr el script de nuevo
DELETE FROM Cliente WHERE dni BETWEEN 45000001 AND 46000010;
GO


-- FUNCIONES

-- Devuelve el stock de un instrumento
CREATE OR ALTER FUNCTION dbo.fn_StockDisponible (@cod_instrumento INT)
RETURNS INT
AS
BEGIN
    RETURN ISNULL((SELECT stock FROM Instrumento WHERE cod_instrumento = @cod_instrumento), 0);
END;
GO

-- Devuelve el total de una venta
CREATE OR ALTER FUNCTION dbo.fn_TotalVenta (@id_venta INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN ISNULL((SELECT SUM(cantidad * precio_unitario)
                   FROM DetalleVenta
                   WHERE id_venta = @id_venta), 0);
END;
GO

-- Devuelve cuántas unidades de un instrumento están disponibles para alquilar
CREATE OR ALTER FUNCTION dbo.fn_UnidadesDisponiblesAlquiler (@cod_instrumento INT)
RETURNS INT
AS
BEGIN
    RETURN (SELECT COUNT(*)
            FROM UnidadInstrumento
            WHERE cod_instrumento = @cod_instrumento
              AND estado = 'Disponible');
END;
GO

-- Devuelve el historial de un cliente: ventas, alquileres y reparaciones
CREATE OR ALTER FUNCTION dbo.fn_HistorialCliente (@id_cliente INT)
RETURNS TABLE
AS
RETURN
(
    SELECT 'Venta' AS tipo, v.id_venta AS nro, CAST(v.fecha_venta AS DATE) AS fecha,
           dbo.fn_TotalVenta(v.id_venta) AS monto
    FROM Venta v
    WHERE v.id_cliente = @id_cliente
    UNION ALL
    SELECT 'Alquiler', a.id_alquiler, a.fecha_entrega, a.seguro_efectivo
    FROM Alquiler a
    WHERE a.id_cliente = @id_cliente
    UNION ALL
    SELECT 'Reparación', o.id_reparacion, o.fecha_ingreso, NULL
    FROM OrdenReparacion o
    JOIN InstrumentoCliente ic ON ic.id_instrumento_cliente = o.id_instrumento_cliente
    WHERE ic.id_cliente = @id_cliente
);
GO


-- PROCEDIMIENTOS

-- Inserta un cliente nuevo
CREATE OR ALTER PROCEDURE dbo.sp_InsertarCliente
    @dni          INT,
    @nombre       VARCHAR(50),
    @apellido     VARCHAR(50),
    @num_telefono VARCHAR(20),
    @id_cliente   INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @dni IS NULL OR @dni <= 0
       OR NULLIF(LTRIM(RTRIM(@nombre)), '') IS NULL
       OR NULLIF(LTRIM(RTRIM(@apellido)), '') IS NULL
       OR NULLIF(LTRIM(RTRIM(@num_telefono)), '') IS NULL
        THROW 50005, 'Faltan datos del cliente o el DNI no es válido.', 1;

    IF EXISTS (SELECT 1 FROM Cliente WHERE dni = @dni)
        THROW 50001, 'Ya existe un cliente con ese DNI (RN01).', 1;

    INSERT INTO Cliente (dni, nombre, apellido, num_telefono)
    VALUES (@dni, @nombre, @apellido, @num_telefono);

    SET @id_cliente = SCOPE_IDENTITY();
END;
GO

-- Modifica los datos de un cliente
CREATE OR ALTER PROCEDURE dbo.sp_ModificarCliente
    @id_cliente   INT,
    @dni          INT,
    @nombre       VARCHAR(50),
    @apellido     VARCHAR(50),
    @num_telefono VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE id_cliente = @id_cliente)
        THROW 50002, 'El cliente no existe.', 1;

    IF @dni IS NULL OR @dni <= 0
       OR NULLIF(LTRIM(RTRIM(@nombre)), '') IS NULL
       OR NULLIF(LTRIM(RTRIM(@apellido)), '') IS NULL
       OR NULLIF(LTRIM(RTRIM(@num_telefono)), '') IS NULL
        THROW 50005, 'Faltan datos del cliente o el DNI no es válido.', 1;

    IF EXISTS (SELECT 1 FROM Cliente WHERE dni = @dni AND id_cliente <> @id_cliente)
        THROW 50001, 'Ese DNI ya pertenece a otro cliente (RN01).', 1;

    UPDATE Cliente
    SET dni = @dni, nombre = @nombre, apellido = @apellido, num_telefono = @num_telefono
    WHERE id_cliente = @id_cliente;
END;
GO

-- Borra un cliente si no tiene ventas, alquileres ni reparaciones
CREATE OR ALTER PROCEDURE dbo.sp_BorrarCliente
    @id_cliente INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE id_cliente = @id_cliente)
        THROW 50002, 'El cliente no existe.', 1;

    IF EXISTS (SELECT 1 FROM Venta WHERE id_cliente = @id_cliente)
       OR EXISTS (SELECT 1 FROM Alquiler WHERE id_cliente = @id_cliente)
       OR EXISTS (SELECT 1 FROM InstrumentoCliente WHERE id_cliente = @id_cliente)
        THROW 50003, 'No se puede borrar: el cliente tiene ventas, alquileres o reparaciones.', 1;

    DELETE FROM Cliente WHERE id_cliente = @id_cliente;
END;
GO

-- Registra una venta con el precio del catálogo y descuenta el stock
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarVenta
    @id_cliente      INT,
    @dni_vendedor    INT,
    @id_metodo_pago  INT,
    @cod_instrumento INT,
    @cantidad        INT,
    @id_venta        INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM Cliente WHERE id_cliente = @id_cliente)
        THROW 50002, 'El cliente no existe.', 1;

    IF NOT EXISTS (SELECT 1 FROM Vendedor WHERE dni_empleado = @dni_vendedor)
        THROW 50006, 'El empleado no existe o no es vendedor (RN04).', 1;

    IF NOT EXISTS (SELECT 1 FROM MetodoPago WHERE id_metodo_pago = @id_metodo_pago)
        THROW 50007, 'El método de pago no existe (RN06).', 1;

    IF NOT EXISTS (SELECT 1 FROM Instrumento WHERE cod_instrumento = @cod_instrumento)
        THROW 50008, 'El instrumento no existe.', 1;

    IF @cantidad IS NULL OR @cantidad <= 0
        THROW 50005, 'La cantidad debe ser mayor a cero.', 1;

    IF dbo.fn_StockDisponible(@cod_instrumento) < @cantidad
        THROW 50004, 'Stock insuficiente.', 1;

    INSERT INTO Venta (id_cliente, dni_vendedor, id_metodo_pago)
    VALUES (@id_cliente, @dni_vendedor, @id_metodo_pago);

    SET @id_venta = SCOPE_IDENTITY();

    INSERT INTO DetalleVenta (id_venta, cod_instrumento, cantidad, precio_unitario)
    SELECT @id_venta, cod_instrumento, @cantidad, precio
    FROM Instrumento
    WHERE cod_instrumento = @cod_instrumento;

    UPDATE Instrumento
    SET stock = stock - @cantidad
    WHERE cod_instrumento = @cod_instrumento;
END;
GO

-- Muestra un cliente, o todos si no se pasa el id
CREATE OR ALTER PROCEDURE dbo.sp_ConsultarCliente
    @id_cliente INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT id_cliente, dni, nombre, apellido, num_telefono
    FROM Cliente
    WHERE @id_cliente IS NULL OR id_cliente = @id_cliente
    ORDER BY id_cliente;
END;
GO


-- Prueba de las funciones
SELECT i.cod_instrumento, i.nombre_instrumento,
       dbo.fn_StockDisponible(i.cod_instrumento)            AS stock_para_venta,
       dbo.fn_UnidadesDisponiblesAlquiler(i.cod_instrumento) AS unidades_para_alquiler
FROM Instrumento i
ORDER BY i.cod_instrumento;

SELECT v.id_venta, CAST(v.fecha_venta AS DATE) AS fecha,
       dbo.fn_TotalVenta(v.id_venta) AS total
FROM Venta v
ORDER BY v.id_venta;

-- Historial del cliente 1
SELECT * FROM dbo.fn_HistorialCliente(1) ORDER BY fecha;
GO


-- Lote de clientes con insert directo
INSERT INTO Cliente (dni, nombre, apellido, num_telefono) VALUES
(45000001, 'Martina',  'Aguirre',  '3794200001'),
(45000002, 'Franco',   'Benítez',  '3794200002'),
(45000003, 'Paula',    'Cáceres',  '3794200003'),
(45000004, 'Ignacio',  'Domínguez','3794200004'),
(45000005, 'Rocío',    'Escobar',  '3794200005'),
(45000006, 'Santiago', 'Franco',   '3794200006'),
(45000007, 'Abril',    'Giménez',  '3794200007'),
(45000008, 'Joaquín',  'Ledesma',  '3794200008'),
(45000009, 'Milagros', 'Maidana',  '3794200009'),
(45000010, 'Thiago',   'Núñez',    '3794200010');

SELECT id_cliente, dni, nombre, apellido, num_telefono
FROM Cliente WHERE dni BETWEEN 45000001 AND 45000010;
GO


-- Lote de clientes usando el procedimiento
DECLARE @nuevo INT;
EXEC dbo.sp_InsertarCliente 46000001, 'Valentín',  'Ojeda',     '3794300001', @nuevo OUTPUT;
PRINT 'Cliente creado con id ' + CAST(@nuevo AS VARCHAR(10));
EXEC dbo.sp_InsertarCliente 46000002, 'Catalina',  'Pereyra',   '3794300002';
EXEC dbo.sp_InsertarCliente 46000003, 'Benjamín',  'Quiroga',   '3794300003';
EXEC dbo.sp_InsertarCliente 46000004, 'Emilia',    'Ramos',     '3794300004';
EXEC dbo.sp_InsertarCliente 46000005, 'Lautaro',   'Sosa',      '3794300005';
EXEC dbo.sp_InsertarCliente 46000006, 'Delfina',   'Toledo',    '3794300006';
EXEC dbo.sp_InsertarCliente 46000007, 'Bautista',  'Urquiza',   '3794300007';
EXEC dbo.sp_InsertarCliente 46000008, 'Guadalupe', 'Vallejos',  '3794300008';
EXEC dbo.sp_InsertarCliente 46000009, 'Facundo',   'Zalazar',   '3794300009';
EXEC dbo.sp_InsertarCliente 46000010, 'Josefina',  'Almirón',   '3794300010';

SELECT id_cliente, dni, nombre, apellido, num_telefono
FROM Cliente WHERE dni BETWEEN 46000001 AND 46000010;
GO

-- Error: DNI repetido
EXEC dbo.sp_InsertarCliente 45000001, 'Otra', 'Persona', '3794999999';
GO


-- Modificación de clientes con el procedimiento
DECLARE @id INT;

SELECT @id = id_cliente FROM Cliente WHERE dni = 45000001;
EXEC dbo.sp_ModificarCliente @id, 45000001, 'Martina', 'Aguirre', '3794555001';

SELECT @id = id_cliente FROM Cliente WHERE dni = 46000001;
EXEC dbo.sp_ModificarCliente @id, 46000001, 'Valentín', 'Ojeda', '3794555002';

EXEC dbo.sp_ConsultarCliente @id;

SELECT id_cliente, dni, nombre, apellido, num_telefono
FROM Cliente WHERE dni IN (45000001, 46000001);
GO

-- Borrado de clientes con el procedimiento
DECLARE @id INT;

SELECT @id = id_cliente FROM Cliente WHERE dni = 45000010;
EXEC dbo.sp_BorrarCliente @id;

SELECT @id = id_cliente FROM Cliente WHERE dni = 46000010;
EXEC dbo.sp_BorrarCliente @id;

SELECT COUNT(*) AS clientes_de_prueba_que_quedan
FROM Cliente WHERE dni BETWEEN 45000001 AND 46000010;
GO

-- Error: el cliente 1 tiene ventas
EXEC dbo.sp_BorrarCliente 1;
GO


-- Venta de un violín (cada vez que se corre registra una venta nueva)

-- Stock antes de la venta
SELECT cod_instrumento, nombre_instrumento, precio, stock
FROM Instrumento WHERE cod_instrumento = 8;

DECLARE @venta INT;
EXEC dbo.sp_RegistrarVenta
     @id_cliente = 3, @dni_vendedor = 30000003, @id_metodo_pago = 1,
     @cod_instrumento = 8, @cantidad = 1, @id_venta = @venta OUTPUT;

-- Venta creada, detalle con el total y stock después de la venta
SELECT v.id_venta, v.fecha_venta, v.id_cliente, v.dni_vendedor, v.id_metodo_pago
FROM Venta v WHERE v.id_venta = @venta;

SELECT dv.id_venta, dv.cod_instrumento, dv.cantidad, dv.precio_unitario,
       dbo.fn_TotalVenta(dv.id_venta) AS total_venta
FROM DetalleVenta dv WHERE dv.id_venta = @venta;

SELECT cod_instrumento, nombre_instrumento, precio, stock
FROM Instrumento WHERE cod_instrumento = 8;
GO

-- Error: el saxo no tiene stock
EXEC dbo.sp_RegistrarVenta 3, 30000003, 1, 7, 1;
GO

-- Error: la venta la hace un técnico
EXEC dbo.sp_RegistrarVenta 3, 30000009, 1, 8, 1;
GO


-- Comparación: 1000 inserts directos contra 1000 con el procedimiento
-- Se deshace todo con ROLLBACK para no dejar clientes de prueba
SET NOCOUNT ON;
DECLARE @i INT, @dni INT, @t0 DATETIME2, @ms_directo INT, @ms_procedimiento INT;

BEGIN TRANSACTION;

SET @i = 1;
SET @t0 = SYSDATETIME();
WHILE @i <= 1000
BEGIN
    INSERT INTO Cliente (dni, nombre, apellido, num_telefono)
    VALUES (50000000 + @i, 'Prueba', 'Directo', '3790000000');
    SET @i += 1;
END;
SET @ms_directo = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());

SET @i = 1;
SET @t0 = SYSDATETIME();
WHILE @i <= 1000
BEGIN
    SET @dni = 51000000 + @i;
    EXEC dbo.sp_InsertarCliente @dni, 'Prueba', 'Procedimiento', '3790000000';
    SET @i += 1;
END;
SET @ms_procedimiento = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());

ROLLBACK TRANSACTION;

SELECT @ms_directo AS ms_1000_insert_directo,
       @ms_procedimiento AS ms_1000_con_procedimiento;
SET NOCOUNT OFF;
GO

-- Comparación: total de las ventas con la función contra la consulta directa, 1000 veces
SET NOCOUNT ON;
DECLARE @i INT, @t0 DATETIME2, @ms_funcion INT, @ms_directa INT, @suma DECIMAL(14,2);

SET @i = 1;
SET @t0 = SYSDATETIME();
WHILE @i <= 1000
BEGIN
    SELECT @suma = SUM(dbo.fn_TotalVenta(v.id_venta)) FROM Venta v;
    SET @i += 1;
END;
SET @ms_funcion = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());

SET @i = 1;
SET @t0 = SYSDATETIME();
WHILE @i <= 1000
BEGIN
    SELECT @suma = SUM(t.total)
    FROM (SELECT v.id_venta, SUM(dv.cantidad * dv.precio_unitario) AS total
          FROM Venta v
          JOIN DetalleVenta dv ON dv.id_venta = v.id_venta
          GROUP BY v.id_venta) AS t;
    SET @i += 1;
END;
SET @ms_directa = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());

SELECT @ms_funcion AS ms_1000_con_funcion,
       @ms_directa AS ms_1000_consulta_directa;
SET NOCOUNT OFF;
GO
