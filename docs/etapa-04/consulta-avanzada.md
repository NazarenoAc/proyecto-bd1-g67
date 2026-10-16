# Consulta avanzada

Qué instrumentos tienen un precio por encima del promedio del catálogo y ya se vendieron, con su categoría, marca y unidades vendidas. Script: `sql/consultas/consulta-avanzada.sql`.

| cod_instrumento | nombre_instrumento | nombre_categoria | nombre_marca | precio | unidades_vendidas |
|---|---|---|---|---|---|
| 1 | Guitarra Stratocaster | Guitarras | Fender | 850000.00 | 2 |
| 10 | Sintetizador Juno | Teclados | Roland | 1500000.00 | 1 |
| 2 | Guitarra Les Paul Standard | Guitarras | Gibson | 1200000.00 | 1 |
| 6 | Batería acústica Export | Baterías | Pearl | 950000.00 | 1 |

![Instrumentos sobre el precio promedio](imagenes/consulta-avanzada.png)

Une cuatro tablas (Instrumento, Categoria, Marca y DetalleVenta) y filtra con una subconsulta, `precio > (SELECT AVG(precio) FROM Instrumento)`. Después agrupa por instrumento y suma las cantidades vendidas.

Para comprobarlo: los 10 instrumentos suman 8.440.000, así que el promedio es 844.000. Cinco lo superan: Stratocaster, Les Paul, Batería Export, Saxo y Juno. El saxo no aparece porque nunca se vendió y el JOIN con DetalleVenta lo deja afuera. La Stratocaster figura con 2 unidades porque está en las ventas 1 y 10.
