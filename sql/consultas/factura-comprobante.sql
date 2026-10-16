/* Factura (venta 10)
 --  FACTURA / COMPROBANTE (venta 10) Arma el comprobante de una venta: 
 encabezado (nro, fecha, cliente, vendedor, forma de pago) y un renglon por instrumento con su subtotal (cantidad x precio unitario). 
 El total acumulado se calcula con una subconsulta que suma los
 renglones de la venta hasta el actual, asi que el ultimo renglon muestra el
 total de la factura. */

SELECT v.id_venta AS nro_comprobante, v.fecha_venta,
       c.nombre + ' ' + c.apellido AS cliente,
       e.nombre + ' ' + e.apellido AS vendedor,
       mp.nombre_metodo AS forma_pago,
       i.nombre_instrumento AS instrumento,
       dv.cantidad, dv.precio_unitario,
       dv.cantidad * dv.precio_unitario AS subtotal,
       (SELECT SUM(d.cantidad * d.precio_unitario)
        FROM DetalleVenta d
        WHERE d.id_venta = dv.id_venta AND d.cod_instrumento <= dv.cod_instrumento) AS total_acumulado

FROM Venta v
JOIN Cliente c ON c.id_cliente = v.id_cliente
JOIN Empleado e ON e.dni_empleado = v.dni_vendedor
JOIN MetodoPago mp ON mp.id_metodo_pago = v.id_metodo_pago
JOIN DetalleVenta dv ON dv.id_venta = v.id_venta
JOIN Instrumento i ON i.cod_instrumento = dv.cod_instrumento
WHERE v.id_venta = 10
ORDER BY dv.cod_instrumento;