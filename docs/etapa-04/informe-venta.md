# Informe de ventas por vendedor

Cuánto vendió cada vendedor en un período: cantidad de ventas, monto total y fecha de la primera y la última venta. Script: `sql/consultas/reporte-agregado.sql`. Lo probamos con el período del 01/01/2026 al 31/03/2026.

| dni_empleado | vendedor | cant_ventas | total_vendido | primera_venta | ultima_venta |
|---|---|---|---|---|---|
| 30000001 | Carlos Méndez | 2 | 2050000.00 | 2026-01-05 10:30 | 2026-02-03 18:20 |
| 30000002 | Laura Paz | 2 | 1620000.00 | 2026-01-12 16:45 | 2026-03-18 17:15 |
| 30000004 | Ana Vega | 1 | 690000.00 | 2026-02-14 12:00 | 2026-02-14 12:00 |
| 30000003 | Diego Ortiz | 1 | 640000.00 | 2026-01-20 11:10 | 2026-01-20 11:10 |
| 30000005 | Martín Ríos | 1 | 620000.00 | 2026-03-01 09:40 | 2026-03-01 09:40 |

![Ventas por vendedor](imagenes/informe-venta.png)

Primero una subconsulta calcula el total de cada venta, así una venta con varios renglones cuenta una sola vez, y después se agrupa por vendedor con COUNT, SUM, MIN y MAX. El rango termina en "menor a 01/04" y no en "hasta 31/03" porque fecha_venta guarda también la hora y una venta del 31 a la tarde quedaría afuera.

Para comprobarlo: Carlos Méndez atendió la venta 1 (850.000) y la 4 (1.200.000), que dan 2.050.000. Laura Paz atendió la 2 (2 x 420.000 = 840.000) y la 7 (780.000), que dan 1.620.000. La columna cant_ventas suma 7, que son las ventas 1 a 7. La 8 es del 5 de abril y queda afuera.
