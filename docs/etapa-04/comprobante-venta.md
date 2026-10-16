# Comprobante de venta

Consulta que arma el comprobante de una venta: encabezado y detalle en la misma salida, con el subtotal de cada renglón y el total acumulado. Script: `sql/consultas/factura-comprobante.sql`.

La probamos con la venta 10 porque es una de las que tiene más de un instrumento.

| nro_comprobante | fecha_venta | cliente | vendedor | forma_pago | instrumento | cantidad | precio_unitario | subtotal | total_acumulado |
|---|---|---|---|---|---|---|---|---|---|
| 10 | 2026-05-10 19:00 | Lucía Herrera | Florencia Luna | Transferencia | Guitarra Stratocaster | 1 | 850000.00 | 850000.00 | 850000.00 |
| 10 | 2026-05-10 19:00 | Lucía Herrera | Florencia Luna | Transferencia | Teclado PSR-E373 | 1 | 420000.00 | 420000.00 | 1270000.00 |

![Comprobante de la venta 10](imagenes/comprobante-venta.png)

El subtotal es cantidad por precio unitario. El total acumulado lo sacamos con una subconsulta que suma los renglones de esa misma venta hasta el instrumento de la fila, así que el último renglón queda con el total de la factura.

Para comprobarlo: la venta 10 tiene id_cliente = 10 y dni_vendedor = 30000008, que en Cliente y Empleado son Lucía Herrera y Florencia Luna, y se pagó con transferencia. Los renglones son 850.000 y 420.000, y 850.000 + 420.000 = 1.270.000, igual que el último total_acumulado.
