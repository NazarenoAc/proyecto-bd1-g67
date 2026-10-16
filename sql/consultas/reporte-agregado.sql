 /* REPORTE AGREGADO (ventas por vendedor, 01/01/2026 al 31/03/2026)
 muestra por cada vendedor la cantidad de ventas, el monto total vendido y la
 fecha de su primera y ultima venta del periodo. La subconsulta del FROM calcula
 primero el total de cada venta, para que COUNT cuente ventas y no renglones de
 detalle. El rango usa ">= inicio y < dia siguiente al fin" porque fecha_venta
 guarda tambien la hora */
-- Reporte agregado (ventas por vendedor, 1/1 al 31/3/2026)
SELECT '2026-01-01' AS desde, '2026-03-31' AS hasta,
       e.dni_empleado, e.nombre + ' ' + e.apellido AS vendedor,
       COUNT(*) AS cant_ventas,
       SUM(t.total_venta) AS total_vendido,
       MIN(t.fecha_venta) AS primera_venta,
       MAX(t.fecha_venta) AS ultima_venta
FROM (SELECT v.id_venta,v.dni_vendedor,v.fecha_venta,
             SUM(dv.cantidad * dv.precio_unitario) AS total_venta
      FROM Venta v
      JOIN DetalleVenta dv ON dv.id_venta = v.id_venta
      WHERE v.fecha_venta >='20260101' AND v.fecha_venta < '20260401'
      GROUP BY v.id_venta,v.dni_vendedor,v.fecha_venta) AS t
JOIN Empleado e ON e.dni_empleado = t.dni_vendedor
GROUP BY e.dni_empleado,e.nombre,e.apellido
ORDER BY total_vendido DESC;