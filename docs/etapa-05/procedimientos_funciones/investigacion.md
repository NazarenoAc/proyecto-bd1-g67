# Procedimientos y funciones almacenadas

Script: [`scripts.sql`](scripts.sql). Capturas: carpeta [`evidencias/`](evidencias/).

## 1. Definición y objetivo

Un **procedimiento almacenado** es código T-SQL guardado en la base con un nombre. Se ejecuta con `EXEC`, recibe parámetros y puede modificar datos (`INSERT`, `UPDATE`, `DELETE`).

Una **función** también es código guardado, pero **siempre devuelve algo** (un valor o una tabla), **no puede modificar datos** y se usa dentro de una consulta.

| | Procedimiento | Función |
|---|---|---|
| Cómo se usa | `EXEC sp_Nombre ...` | dentro de `SELECT`, `WHERE` o `FROM` |
| Devuelve | opcional (parámetros `OUTPUT`) | siempre un valor o una tabla |
| Modifica datos | sí | no |

El objetivo es que las operaciones de Sonora Instrumentos se hagan siempre igual y con las reglas de negocio controladas por la base.

## 2. Ventajas y aplicaciones

- **Reutilización:** la lógica se escribe una vez.
- **Reglas centralizadas:** las validaciones (DNI único, stock, que venda un vendedor) viven en la base.
- **Seguridad:** se puede permitir ejecutar un procedimiento sin dar acceso directo a la tabla (ver tema de permisos).
- **Rendimiento:** el plan de ejecución se reutiliza y la aplicación hace una sola llamada.

Se aplican en ABM con validación, operaciones completas (una venta) y cálculos repetidos (totales, disponibilidad).

## 3. Implementación en SQL Server

- `CREATE OR ALTER PROCEDURE` / `CREATE OR ALTER FUNCTION`: crea el objeto o lo reemplaza, así el script se puede volver a correr.
- Los parámetros y variables llevan `@` (`@dni`). En `WHERE dni = @dni`, `dni` es la columna y `@dni` el valor recibido.
- `THROW 5000x, 'mensaje', 1` corta la ejecución con un error propio.
- `SCOPE_IDENTITY()` devuelve el id recién generado.
- Cada `CREATE` va en su propio lote, separado con `GO`.

## 4. Caso concreto en Sonora Instrumentos

**Procedimientos (CRUD de `Cliente` + venta):**

| Procedimiento | Qué hace | Valida |
|---|---|---|
| `sp_InsertarCliente` | alta; devuelve el id nuevo | datos completos, DNI no repetido (RN01) |
| `sp_ConsultarCliente` | con id devuelve ese cliente, sin id lista todos | — |
| `sp_ModificarCliente` | modifica los datos | que exista, DNI no usado por otro |
| `sp_BorrarCliente` | baja | que exista y no tenga ventas, alquileres ni reparaciones |
| `sp_RegistrarVenta` | inserta `Venta` y `DetalleVenta` y descuenta stock | cliente, vendedor (RN04), método de pago (RN06), instrumento, cantidad y stock |

`sp_RegistrarVenta` toma el precio del catálogo (RN05) y descuenta `Instrumento.stock`, dos cosas que antes no hacía la base. En el tema de transacciones se ejecuta dentro de `BEGIN TRANSACTION ... COMMIT`.

**Funciones:**

| Función | Devuelve | RN |
|---|---|---|
| `fn_StockDisponible(@cod_instrumento)` | stock para vender (la usa `sp_RegistrarVenta`) | — |
| `fn_TotalVenta(@id_venta)` | total de la venta | RN05 |
| `fn_UnidadesDisponiblesAlquiler(@cod_instrumento)` | unidades "Disponible" | RN07, RN09 |
| `fn_HistorialCliente(@id_cliente)` | tabla con ventas, alquileres y reparaciones | RN04, RN08, RN10 |

## 5. Script de demostración y resultados

El script se ejecuta por secciones en SSMS. La sección 0 borra los clientes de prueba, así se puede correr varias veces.

| Sección | Qué se prueba | Resultado | Captura |
|---|---|---|---|
| 3 | Funciones sobre los datos actuales | el total de la venta 10 da 1.270.000, igual que la etapa 4 | `01-funciones.png` |
| 4 | Lote A: 10 clientes con `INSERT` directo | DNI 45000001 a 45000010 | `02-lote-insert-directo.png` |
| 5 | Lote B: 10 clientes con `sp_InsertarCliente` | DNI 46000001 a 46000010 | `03-lote-procedimiento.png` |
| 6 | `sp_ModificarCliente`, `sp_ConsultarCliente`, `sp_BorrarCliente` | 2 teléfonos cambiados, 2 clientes borrados, quedan 18 | `04-update-delete.png` |
| 7 | `sp_RegistrarVenta`: 1 violín al cliente 3 | stock del violín: 7 → 6; total 310.000 | `05-venta.png` |
| 8 | Comparación de eficiencia | ver tabla de abajo | `06-eficiencia.png` |

**Pruebas de error** (captura `07-errores.png`):

| Prueba | Mensaje |
|---|---|
| Insertar un DNI que ya existe | `50001` Ya existe un cliente con ese DNI (RN01). |
| Borrar el cliente 1, que tiene ventas | `50003` No se puede borrar: el cliente tiene ventas, alquileres o reparaciones. |
| Vender un saxo (stock 0) | `50004` Stock insuficiente. |
| Venta atendida por un técnico | `50006` El empleado no existe o no es vendedor (RN04). |

En los errores no se inserta nada: las validaciones cortan antes del primer `INSERT`.

**Eficiencia** (los tiempos varían un poco en cada ejecución):

| Prueba (1.000 repeticiones) | Directo | Con procedimiento o función |
|---|---|---|
| Insertar clientes | 10 ms | 25 ms |
| Calcular el total de las ventas | 29 ms | 36 ms |

Los inserts de esta prueba se deshacen con `ROLLBACK`, pero el contador `IDENTITY` no vuelve atrás: en una nueva ejecución los ids siguen después de los números ya usados.

## Conclusiones

- El procedimiento fue más lento que el `INSERT` directo porque valida antes de insertar. A cambio, garantiza que no entren DNIs repetidos ni datos incompletos.
- La función escalar fue más lenta que el `JOIN` con `SUM` porque se evalúa una vez por venta. Conviene para no repetir lógica, sabiendo que sobre muchas filas cuesta más.
- Con `sp_RegistrarVenta` la base hace cumplir reglas que antes dependían de quien cargaba los datos: el stock se descuenta, el precio sale del catálogo y solo un vendedor registra ventas.
