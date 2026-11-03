# Manejo de transacciones y transacciones anidadas

Script: [`scripts.sql`](scripts.sql). Capturas: carpeta [`evidencias/`](evidencias/).

## 1. Definición y objetivo

Una **transacción** es un grupo de operaciones que se ejecuta como una sola unidad: o se guardan todas (`COMMIT`) o no se guarda ninguna (`ROLLBACK`). Cumple las propiedades ACID:

- **Atomicidad:** todo o nada.
- **Consistencia:** la base pasa de un estado válido a otro válido.
- **Aislamiento:** otras sesiones no ven los cambios a medio hacer.
- **Durabilidad:** lo confirmado no se pierde.

Una **transacción anidada** es una transacción abierta dentro de otra. En SQL Server solo la externa decide: el `COMMIT` de la interna no guarda nada. Para deshacer solo una parte se usan **puntos de guardado** (`SAVE TRANSACTION`).

El objetivo es que una venta de Sonora Instrumentos nunca quede a medias: si se registra la venta, también tienen que quedar su detalle y el stock descontado.

## 2. Ventajas y aplicaciones

- Evitan datos inconsistentes cuando una operación tiene varios pasos (por ejemplo, una venta sin detalle o un stock sin descontar).
- Permiten manejar errores: si algo falla, se vuelve al estado anterior.
- Con los puntos de guardado se puede descartar una parte y conservar el resto.

Se aplican en ventas, transferencias, altas que afectan varias tablas y cualquier proceso de varios pasos.

## 3. Implementación en SQL Server

```sql
BEGIN TRY
    BEGIN TRANSACTION;
    -- operaciones
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;
```

- `BEGIN TRANSACTION` abre la transacción; `COMMIT` la confirma; `ROLLBACK` la deshace.
- `TRY...CATCH`: si hay un error en el `TRY`, la ejecución pasa al `CATCH`, donde se hace el `ROLLBACK`.
- `@@TRANCOUNT` indica cuántas transacciones hay abiertas. Cada `BEGIN TRANSACTION` lo sube en 1 y cada `COMMIT` lo baja en 1; un `ROLLBACK` lo deja en 0.
- `SAVE TRANSACTION nombre` marca un punto; `ROLLBACK TRANSACTION nombre` deshace solo hasta ahí.
- `SET XACT_ABORT ON` hace que cualquier error deshaga la transacción completa.

## 4. Caso concreto en Sonora Instrumentos

Registrar una venta toca tres tablas, igual que pide la consigna:

1. **Insert** en `Venta` (el encabezado).
2. **Insert** en `DetalleVenta` (el instrumento, la cantidad y el precio).
3. **Update** de `Instrumento.stock` (descontar las unidades).

Si falla cualquier paso, la venta no debe quedar registrada. Se usa el teclado (cod 4) porque está por debajo del precio promedio y no altera las consultas de la etapa 4. También se ejecuta `sp_RegistrarVenta` del tema anterior dentro de una transacción, como propone la guía.

Por último, `sp_RegistrarVentaTransaccional` lleva la transacción adentro del procedimiento, con `XACT_ABORT ON` y un parámetro `@forzar_error` que provoca un error después del insert en `Venta`. Para esta prueba se usa la guitarra RG (cod 9), también por debajo del precio promedio.

## 5. Script de demostración y resultados

Resultados de una ejecución con la base recién cargada y el tema 1 ya ejecutado. Cada corrida completa vende 3 teclados (stock 6) y 1 guitarra RG (stock 3), así que el script se puede correr dos veces seguidas.

| Prueba | Antes (ventas / detalles / stock) | Resultado | Después | Captura |
|---|---|---|---|---|
| Transacción completa | 11 / 12 / 6 | Venta confirmada | 12 / 13 / 5 | `01-transaccion-exitosa.png` |
| Error provocado después del insert | 12 / 13 / 5 | la venta se insertó (id 13) y el `ROLLBACK` la deshizo | 12 / 13 / 5 | `02-error-despues-del-insert.png` |
| `sp_RegistrarVenta` en transacción | 12 / 13 / 5 | Venta confirmada | 13 / 14 / 4 | `03-procedimiento.png` |
| `sp_RegistrarVenta` pidiendo 100 unidades | 13 / 14 / 4 | Stock insuficiente, se deshace | 13 / 14 / 4 | `03-procedimiento.png` |

**Error después del insert:** la consulta final muestra `existe_venta_insertada = 0`. La venta 13 llegó a insertarse, pero no quedó guardada, y tampoco se insertó el detalle ni se tocó el stock.

**Transacción anidada** (captura `04-anidada.png`):

| Estado | `@@TRANCOUNT` |
|---|---|
| Externa abierta | 1 |
| Interna abierta | 2 |
| Interna confirmada (`COMMIT`) | 1 |
| Externa deshecha (`ROLLBACK`) | 0 |

Antes y después: 13 ventas y 14 detalles. El detalle que se "confirmó" en la interna también se perdió.

**Punto de guardado** (captura `05-save-transaction.png`): una venta de teclado + saxo. El saxo no tiene stock y el `UPDATE` falla por la restricción `CK_Instrumento_stock`. Se hace `ROLLBACK TRANSACTION segundo_item`, que deshace solo el saxo, y la venta se confirma con el teclado. Stock final: teclado 3, saxo 0.

**Procedimiento con la transacción adentro** (captura `06-procedimiento-transaccional.png`):

| Prueba | Antes (ventas / detalles / stock RG) | Resultado | Después |
|---|---|---|---|
| Venta de una guitarra RG | 14 / 15 / 3 | Venta confirmada (id 17) | 15 / 16 / 2 |
| `@forzar_error = 1` | 15 / 16 / 2 | Error provocado después del insert en Venta; se deshace | 15 / 16 / 2 |
| Pedir 100 unidades | 15 / 16 / 2 | falla el `CHECK` del stock en el último paso; se deshacen también los dos insert | 15 / 16 / 2 |

Los ids 13, 15, 18 y 19 no aparecen en la tabla `Venta`: se usaron en transacciones deshechas, y el `ROLLBACK` no devuelve los números de `IDENTITY`.

## Conclusiones

- Con la transacción, un error en cualquier paso deja la base igual que antes: no quedan ventas sin detalle ni stock descontado de más.
- El `TRY...CATCH` es necesario para atrapar el error y hacer el `ROLLBACK`. Sin él, la transacción podría quedar abierta.
- En las transacciones anidadas solo cuenta la externa: el `COMMIT` interno no guarda nada y el `ROLLBACK` externo deshace todo.
- `SAVE TRANSACTION` permite descartar una parte (un ítem sin stock) y conservar el resto de la operación.
- Poner la transacción adentro del procedimiento es más seguro: quien lo llama no puede olvidarse de abrirla ni de cerrarla, y el `THROW` del `CATCH` le avisa del error.
