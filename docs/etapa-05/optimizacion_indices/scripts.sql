-- Etapa V - Optimizacion de consultas con indices
-- Base: SonoraInstrumentos
--

USE SonoraInstrumentos;
GO


-- PARTE 1 - tabla de pruebas
-- La armo aparte para no tocar las ventas reales,a proposito no tiene clave primaria
-- ni indices, asi queda como heap y la primera consulta tiene que recorrerla toda
DROP TABLE IF EXISTS dbo.VentaHistorica;
GO

CREATE TABLE dbo.VentaHistorica
(
    id_venta        BIGINT IDENTITY(1,1),
    fecha_venta     DATE NOT NULL,
    cod_instrumento INT NOT NULL,
    importe         DECIMAL(12,2) NOT NULL
);
GO


-- PARTE 2 - carga de 1.000.000 de filas
-- fechas entre 2020-01-01 y 2024-12-30, instrumento del 1 al 10 (como el catalogo)
-- e importe entre 10.000 y 1.500.000  con dos CROSS JOIN de sys.all_objects ya
-- sobran filas para llegar al millon.
SET NOCOUNT ON;
GO

WITH Numeros AS
(
    SELECT TOP (1000000)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.VentaHistorica (fecha_venta, cod_instrumento, importe)
SELECT
    CAST(DATEADD(DAY, ABS(CHECKSUM(NEWID()) % 1825), '2020-01-01') AS DATE),
    1 + ABS(CHECKSUM(NEWID()) % 10),
    CAST(10000 + RAND(CHECKSUM(NEWID())) * 1490000 AS DECIMAL(12,2))
FROM Numeros;
GO

-- tiene que dar 1000000
SELECT COUNT(*) AS CantidadRegistros
FROM dbo.VentaHistorica;
GO

-- cuantas filas entran en el filtro de las pruebas (primer trimestre de 2023)
SELECT COUNT(*) AS filas_primer_trimestre_2023
FROM dbo.VentaHistorica
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO


-- PARTE 3 - consulta sin indices
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO


SELECT id_venta, fecha_venta, importe
FROM dbo.VentaHistorica
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO
-- anotar: CPU, tiempo total, lecturas logicas, operador y % de costo
-- captura: evidencias/01-sin-indice.png


-- PARTE 4 - indice agrupado (clustered) sobre la fecha
CREATE CLUSTERED INDEX IX_VentaHistorica_Fecha
ON dbo.VentaHistorica (fecha_venta);
GO

-- la misma consulta de la parte 3
SELECT id_venta, fecha_venta, importe
FROM dbo.VentaHistorica
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO
-- anotar lo mismo. Deberia aparecer un Clustered Index Seek
-- captura: evidencias/02-indice-agrupado.png


-- PARTE 5 - borrar el indice agrupado (la tabla vuelve a ser un heap)
DROP INDEX IX_VentaHistorica_Fecha
ON dbo.VentaHistorica;
GO


-- PARTE 6 - indice no agrupado con cobertura
-- la fecha va en la clave porque es lo que filtramos, e importe en el INCLUDE
-- porque es lo que devolvemos. Asi no hace falta ir a buscar nada a la tabla
CREATE NONCLUSTERED INDEX IX_VentaHistorica_Fecha_Cobertura
ON dbo.VentaHistorica (fecha_venta)
INCLUDE (importe);
GO

-- ahora la consulta pide solo fecha_venta e importe, que es lo que tiene el indice
SELECT fecha_venta, importe
FROM dbo.VentaHistorica
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO
-- anotar lo mismo. Deberia aparecer un Index Seek
-- captura: evidencias/03-indice-cobertura.png


-- PARTE 7  - la consulta de la parte 3 con el indice de cobertura
-- Esta vuelve a pedir id_venta, que no esta en el indice. Mirar que plan elige
-- el motor: puede ser usar el indice y buscar cada fila en la tabla, o recorrer
-- la tabla entera. Anotar cual hizo
SELECT id_venta, fecha_venta, importe
FROM dbo.VentaHistorica
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO
-- captura: evidencias/04-consulta-no-cubierta.png


-- PARTE 8  - cuanto espacio ocupan
-- Se mide con el indice de cobertura ya creado. La fila (heap) es la tabla sola,
-- asi se ve cuanto suma el indice
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

SELECT ISNULL(i.name, '(heap)') AS indice,
       i.type_desc               AS tipo,
       CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(10,2)) AS tamano_mb
FROM sys.dm_db_partition_stats ps
JOIN sys.indexes i
  ON i.object_id = ps.object_id AND i.index_id = ps.index_id
WHERE ps.object_id = OBJECT_ID('dbo.VentaHistorica')
GROUP BY i.name, i.type_desc;
GO
-- captura: evidencias/05-tamano-indices.png


-- PARTE 9  - volver a medir sin indices
-- Despues de crear y borrar el indice agrupado la tabla quedo ocupando mas paginas
-- que cuando se cargo (la primera medicion sin indice dio menos lecturas). Para comparar
-- contra la misma tabla se borra el indice de cobertura y se repite la consulta de la parte 3.
-- Estos son los valores del escenario 1 de investigacion.md.
DROP INDEX IX_VentaHistorica_Fecha_Cobertura
ON dbo.VentaHistorica;
GO

SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

SELECT id_venta, fecha_venta, importe
FROM dbo.VentaHistorica
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
GO
-- captura: evidencias/01-sin-indice.png
-- para dejar la tabla como termina la parte 8, volver a correr el CREATE INDEX de la parte 6
