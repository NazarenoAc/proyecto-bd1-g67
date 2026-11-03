# Optimización de consultas a través de índices

Script: [`scripts.sql`](scripts.sql). Capturas: carpeta [`evidencias/`](evidencias/).

## 1. Definición y objetivo

Un **índice** es una estructura que SQL Server guarda aparte de los datos para encontrar filas sin recorrer toda la tabla, como el índice de un libro. Sin índice, para responder un filtro el motor lee todas las filas (**Table Scan** si la tabla no tiene índice agrupado, **Clustered Index Scan** si lo tiene). Con un índice adecuado puede ir directo a las filas buscadas (**Seek**).

Hay dos tipos principales:

- **Índice agrupado (clustered):** ordena físicamente la tabla por la clave elegida, así que la tabla *es* el índice. Solo puede haber uno por tabla.
- **Índice no agrupado (nonclustered):** es una estructura separada que apunta a las filas de la tabla. Puede haber muchos. Con `INCLUDE` se le agregan columnas que no forman parte de la clave pero se guardan en el índice.

Un índice **cubre** una consulta cuando tiene todas las columnas que la consulta necesita (las del filtro y las que devuelve). En ese caso el motor responde leyendo solo el índice, sin acceder a la tabla.

El objetivo es medir cuánto mejora una consulta de ventas por período en Sonora Instrumentos al pasar de no tener índices a tener uno agrupado y a tener uno con cobertura.

## 2. Ventajas y aplicaciones

- Reducen las lecturas de páginas y el tiempo de las consultas con filtros (fechas, códigos, clientes, instrumentos).
- Se notan sobre todo en tablas grandes, y permiten que el sistema siga respondiendo bien cuando crecen los datos.
- Un índice con cobertura evita ir a buscar cada fila a la tabla.

Desventajas a tener en cuenta:

- Ocupan espacio en disco.
- Cada `INSERT`, `UPDATE` o `DELETE` también tiene que actualizar los índices, así que las escrituras se vuelven algo más costosas.
- Solo conviene indexar las columnas que realmente se usan en filtros, joins u ordenamientos.

Se aplican en reportes por período, búsquedas por código o cliente y joins entre tablas grandes.

## 3. Implementación en SQL Server

```sql
-- Índice agrupado
CREATE CLUSTERED INDEX IX_nombre ON tabla (columna);

-- Índice no agrupado con cobertura
CREATE NONCLUSTERED INDEX IX_nombre ON tabla (columna_filtro) INCLUDE (columna_devuelta);

-- Eliminar un índice
DROP INDEX IX_nombre ON tabla;
```

Para medir se usan estas herramientas de SSMS:

- `SET STATISTICS TIME ON`: muestra el tiempo de CPU y el tiempo total (*elapsed*) de cada consulta.
- `SET STATISTICS IO ON`: muestra las **lecturas lógicas** (*logical reads*), es decir, las páginas que leyó el motor. Es la métrica más estable entre ejecuciones y entre computadoras.
- **Plan de ejecución real** (`Ctrl + M` antes de ejecutar): muestra el operador que eligió el optimizador (Scan, Seek, Lookup) y el porcentaje de costo de cada uno.

## 4. Caso concreto en Sonora Instrumentos

Las tablas reales (`Venta` y `DetalleVenta`) tienen pocas filas, así que no sirven para ver la diferencia. Se crea una tabla de pruebas, `VentaHistorica`, con la forma de una venta del negocio y un millón de filas:

| Columna | Tipo | Descripción |
|---|---|---|
| `id_venta` | `BIGINT IDENTITY` | Número de venta |
| `fecha_venta` | `DATE` | Entre 2020-01-01 y 2024-12-30 |
| `cod_instrumento` | `INT` | Instrumento vendido (1 a 10, como el catálogo) |
| `importe` | `DECIMAL(12,2)` | Entre 10.000 y 1.500.000 |

La tabla se crea sin clave primaria y sin índices a propósito, para que la primera consulta recorra toda la tabla.

La consulta de prueba es un reporte de las ventas del primer trimestre de 2023, que corresponde a unas 49.000 filas (alrededor del 5 % de la tabla):

```sql
SELECT id_venta, fecha_venta, importe
FROM VentaHistorica
WHERE fecha_venta BETWEEN '2023-01-01' AND '2023-03-31';
```

Se compara en tres escenarios:

| Escenario | Estructura |
|---|---|
| 1. Sin índice | Tabla sin índices (heap) |
| 2. Índice agrupado | `IX_VentaHistorica_Fecha` sobre `fecha_venta` |
| 3. Índice con cobertura | `IX_VentaHistorica_Fecha_Cobertura` sobre `fecha_venta`, con `INCLUDE (importe)` |

En el escenario 3 la consulta se reduce a `SELECT fecha_venta, importe`, que es lo único que el índice contiene. Como parte extra, se vuelve a ejecutar la consulta completa (con `id_venta`) sobre ese mismo índice para ver qué hace el optimizador cuando el índice ya no la cubre.

En el sistema real, la misma idea se aplicaría a las columnas que se usan para unir tablas, por ejemplo `DetalleVenta.cod_instrumento` (usada en la consulta avanzada de la etapa 4). SQL Server crea índice automáticamente para las claves primarias y las restricciones `UNIQUE`, pero no para las claves foráneas.

## 5. Script de demostración y resultados

Todo el procedimiento está en [`scripts.sql`](scripts.sql), dividido en partes numeradas. Se ejecutó en SQL Server Express (SSMS 22) con las estadísticas de tiempo y de lectura activadas y el plan de ejecución real. Los valores dependen del hardware.

Filas de la tabla: **1.000.000**. Filas del primer trimestre de 2023: **48.928**.

**Resultados de las consultas**

| Escenario | Tiempo CPU (ms) | Tiempo total (ms) | Lecturas lógicas | Operación principal | % de costo | Capturas |
|---|---|---|---|---|---|---|
| 1. Sin índice | 110 | 409 | 5.077 | Table Scan | 100 % | `01-sin-indice.png` |
| 2. Índice agrupado sobre fecha | 15 | 322 | 253 | Clustered Index Seek | 100 % | `02-indice-agrupado.png` |
| 3. Índice con cobertura | 15 | 297 | 162 | Index Seek (NonClustered) | 100 % | `03-indice-cobertura.png` |
| Extra: consulta con `id_venta` sobre el índice de cobertura | 140 | 437 | 5.077 | Table Scan | 100 % | `04-consulta-no-cubierta.png` |

Cada escenario tiene dos capturas: el plan de ejecución (`NN-nombre.png`) y la pestaña de mensajes con los tiempos y las lecturas (`NN-nombre-mensajes.png`).

Cómo se tomaron los valores:

- Cada valor es la **segunda ejecución** de la consulta, cuando el plan ya está compilado y los datos están en memoria. La primera ejecución con el índice agrupado, por ejemplo, tardó más (47 ms de CPU y 638 ms en total).
- La primera vez que se midió sin índice, con la tabla recién cargada, dio 4.082 lecturas lógicas (204 ms de CPU y 371 ms en total). Después de crear y borrar el índice agrupado, la tabla pasó a ocupar más páginas (5.077). Por eso se volvió a medir sin índice, borrando antes el índice de cobertura (parte 9 del script), y la tabla de arriba usa esa medición, que es la misma tabla con la que se comparan los otros escenarios.
- Los milisegundos cambian de una ejecución a otra, y el tiempo total incluye mostrar las 48.928 filas en SSMS. Por eso la comparación más confiable son las **lecturas lógicas**.

**Tamaño de las estructuras** (captura `05-tamano-indices.png`):

| Estructura | Tipo | Tamaño (MB) |
|---|---|---|
| Tabla (heap) | HEAP | 39,67 |
| `IX_VentaHistorica_Fecha_Cobertura` | NONCLUSTERED | 25,20 |

**Qué se observó:**

1. **Sin índice**, el motor recorrió toda la tabla (Table Scan) y leyó 5.077 páginas para devolver unas 49.000 filas.
2. **Con el índice agrupado** el plan pasó a Clustered Index Seek y las lecturas bajaron a 253, unas 20 veces menos, porque solo se leen las páginas del rango de fechas.
3. **Con el índice de cobertura** las lecturas bajaron a 162, unas 31 veces menos que sin índice. El índice es más angosto que la tabla (solo guarda `fecha_venta` e `importe`) y la consulta se resuelve sin acceder a la tabla.
4. **En el caso extra**, la consulta pide también `id_venta`, que no está en el índice. El optimizador **no usó el índice** y volvió a recorrer toda la tabla (5.077 lecturas, igual que sin índice), porque usarlo obligaba a buscar `id_venta` en la tabla para cada una de las unas 49.000 filas encontradas. El plan incluyó una sugerencia de "índice faltante" (impacto 82,93) que propone justamente agregar `id_venta` al `INCLUDE`.

## Conclusiones

- Un índice sobre la columna del filtro cambia el plan de un escaneo completo a una búsqueda (Seek). En esta prueba las lecturas lógicas pasaron de 5.077 a 253 con el índice agrupado y a 162 con el de cobertura.
- El índice con cobertura es el que menos páginas lee, pero solo sirve a las consultas que piden columnas incluidas en él. Cuando se agregó `id_venta`, el optimizador lo descartó y recorrió la tabla.
- Las lecturas lógicas comparan mejor que los milisegundos: los tiempos variaron entre ejecuciones (caché, plan compilado, mostrar los resultados en pantalla).
- Los índices tienen un costo. El índice de cobertura ocupa 25,20 MB, alrededor del 64 % del tamaño de la tabla (39,67 MB), y además hay que mantenerlo actualizado en cada `INSERT`, `UPDATE` o `DELETE`. Se crean para las consultas frecuentes, no para todas las columnas.
- En Sonora Instrumentos el volumen actual es chico, pero si el historial de ventas creciera, convendría indexar `Venta.fecha_venta` (reportes por período) y las claves foráneas usadas en joins.
