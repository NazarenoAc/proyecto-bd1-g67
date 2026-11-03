# Triggers de auditoría

Script: [`scripts.sql`](scripts.sql). Capturas: carpeta [`evidencias/`](evidencias/).

## 1. Definición y objetivo

Un **trigger** (disparador) es un procedimiento almacenado asociado a una tabla que SQL Server ejecuta automáticamente cuando ocurre un `INSERT`, `UPDATE` o `DELETE` sobre ella. No se invoca: se activa solo, dentro de la misma transacción de la operación que lo disparó.

Dentro de un trigger hay dos tablas virtuales:

| Tabla virtual | En INSERT | En UPDATE | En DELETE |
|---|---|---|---|
| `inserted` | filas nuevas | valores **nuevos** | vacía |
| `deleted` | vacía | valores **anteriores** | filas eliminadas |

| Tipo | Cuándo se ejecuta | Uso típico |
|---|---|---|
| `AFTER` (o `FOR`) | después de la operación y de las restricciones | auditoría, reglas posteriores |
| `INSTEAD OF` | en lugar de la operación, que no se ejecuta salvo que el trigger la reproduzca | bloquear o reemplazar operaciones |
| DDL | ante `CREATE`, `ALTER`, `DROP` | auditar cambios de estructura |
| LOGON | al iniciar sesión | control de accesos |

El objetivo es dar trazabilidad a los cambios de Sonora Instrumentos (quién, cuándo y qué valor había antes) y proteger el historial de ventas impidiendo su borrado.

## 2. Ventajas y aplicaciones

- **Trazabilidad:** responde a "¿quién cambió el precio?", "¿cuándo se borró este cliente?" y "¿qué valor tenía antes?".
- **Automatismo:** la auditoría no depende de que la aplicación se acuerde de registrar el cambio.
- **Seguridad:** quien modifica datos directamente desde SQL también queda registrado.
- **Integridad:** un `INSTEAD OF` puede impedir operaciones que las restricciones declarativas no cubren.
- **Centralización:** la regla vive en la base y se aplica sin importar desde dónde se accede.

**Costos:** cada operación auditada hace una escritura extra, y los triggers son "invisibles" para quien lee el código de la aplicación, por lo que conviene no abusar de ellos.

## 3. Implementación en SQL Server

- **Tablas auditadas:** `Instrumento` (precio y stock son datos sensibles) y `Cliente` (datos personales).
- **Tablas auxiliares:** `AuditoriaInstrumento` y `AuditoriaCliente`. Guardan los valores **anteriores** de todas las columnas, más `operacion` (`UPDATE` o `DELETE`), `fecha_hora` (`GETDATE()`), `usuario_bd` (`USER_NAME()`) y `login_servidor` (`SUSER_SNAME()`).
- **Sin FK hacia la tabla original:** si el registro se borra, su auditoría tiene que sobrevivir.
- **Un trigger por evento y tabla**, que toma los valores anteriores de `deleted` con `INSERT ... SELECT`. Una sentencia que modifica varias filas genera una fila de auditoría por cada una.
- **Bloqueo del borrado:** `trg_Venta_BloquearDelete` es un `INSTEAD OF DELETE` sobre `Venta`. Como no ejecuta el borrado, la venta no se elimina y tampoco se dispara el `ON DELETE CASCADE` hacia `DetalleVenta`. Corta con `THROW 50020`, un código que no se repite con los de los otros temas (50001 a 50012).

| Trigger | Tabla | Tipo | Función |
|---|---|---|---|
| `trg_Instrumento_AuditUpdate` | `Instrumento` | AFTER UPDATE | registra los valores previos |
| `trg_Instrumento_AuditDelete` | `Instrumento` | AFTER DELETE | registra el instrumento borrado |
| `trg_Cliente_AuditUpdate` | `Cliente` | AFTER UPDATE | registra los valores previos |
| `trg_Cliente_AuditDelete` | `Cliente` | AFTER DELETE | registra el cliente borrado |
| `trg_Venta_BloquearDelete` | `Venta` | INSTEAD OF DELETE | cancela el borrado con un mensaje |

Dos detalles que condicionan el diseño:

- Un `INSTEAD OF DELETE` no se puede crear sobre una tabla que tenga una FK con `ON DELETE CASCADE` definida en ella (por ejemplo `DetalleVenta`). `Venta` solo tiene `ON DELETE NO ACTION`, así que admite el trigger.
- Las FK `NO ACTION` se verifican antes de ejecutar un trigger `AFTER`. Si se intenta borrar un instrumento o un cliente con registros asociados, la FK rechaza la operación y no queda auditoría: solo se audita lo que realmente se modificó.

## 4. Caso concreto en Sonora Instrumentos

- **Cambio de precio:** alguien actualiza el precio de la Stratocaster (cod 1) de $850.000 a $900.000. El trigger guarda el precio anterior, el usuario y la fecha.
- **Baja de un cliente:** se borra un cliente sin operaciones. Su DNI, nombre, apellido y teléfono quedan en `AuditoriaCliente`.
- **Intento de borrar una venta:** alguien ejecuta `DELETE FROM Venta`. El trigger lo rechaza y la venta y su detalle siguen intactos.

**Relación con los otros temas:**

- `sp_RegistrarVenta` y `sp_RegistrarVentaTransaccional` hacen `UPDATE Instrumento SET stock`, así que cada venta deja una fila en `AuditoriaInstrumento` con el stock anterior.
- `sp_ModificarCliente` y `sp_BorrarCliente` disparan los triggers de `Cliente`. Como `sp_BorrarCliente` valida antes de borrar, solo se audita lo que se borró.
- El trigger corre dentro de la transacción: si hay `ROLLBACK` (por ejemplo con `@forzar_error = 1`), la fila de auditoría también se deshace.
- Como `usuario_bd` y `login_servidor` quedan registrados, cuando se aplique el tema de permisos se va a ver qué usuario hizo cada cambio.

## 5. Script de demostración y resultados

Resultados de una ejecución con la base cargada y los temas anteriores ya ejecutados. Las pruebas que modifican datos se hacen dentro de una transacción y terminan con `ROLLBACK`, así el script se puede correr varias veces y no altera los stocks, precios ni clientes de los otros temas. Cada prueba muestra solo las filas de auditoría que generó.

| Prueba | Operación | Resultado | Captura |
|---|---|---|---|
| 1 | `UPDATE` de precio del instrumento 1 a 900.000 | 1 fila `UPDATE` con `precio_ant = 850000.00`; después del `ROLLBACK` el precio vuelve a 850.000 | `01-update-precio.png` |
| 2 | `UPDATE` de stock de la categoría 3 | 1 fila por instrumento afectado (cod 4, 5 y 10) | `02-update-multiple.png` |
| 3 | `DELETE` de un instrumento sin ventas | 1 fila `DELETE` con los valores del instrumento | `03-delete-instrumento.png` |
| 4 | `DELETE` del instrumento 1 (tiene ventas) | error 547 por FK; 0 filas de auditoría | `04-delete-instrumento-fk.png` |
| 5 | `UPDATE` del teléfono del cliente 1 | 1 fila `UPDATE` con `num_telefono_ant = '3794111111'` | `05-update-cliente.png` |
| 6 | `DELETE` de un cliente sin operaciones | 1 fila `DELETE` con los datos del cliente | `06-delete-cliente.png` |
| 7 | `DELETE FROM Venta WHERE id_venta = 1` | error 50020; ventas y detalles antes = después | `07-delete-venta-bloqueado.png` |
| 8 | `DELETE FROM Venta` (masivo) | mismo error; ventas antes = después | `08-delete-venta-masivo.png` |
| 9 | `sp_RegistrarVenta` de 1 teclado (cod 4) | 1 fila `UPDATE` con el stock anterior del teclado | `09-venta-con-procedimiento.png` |

En todas las filas de auditoría aparecen la fecha y hora, el usuario de la base (`usuario_bd`) y el inicio de sesión (`login_servidor`).

Los `ROLLBACK` deshacen las filas de auditoría, pero el contador `IDENTITY` no vuelve atrás: los `id_auditoria` pueden tener saltos.

## Conclusiones

- Los triggers `AFTER` registran el estado previo de cada fila modificada o borrada, incluso cuando una sentencia afecta a varias filas, gracias a la tabla `deleted`.
- Cada cambio queda asociado a una fecha, un usuario y un login, lo que permite reconstruir qué valor había antes y quién lo cambió.
- El `INSTEAD OF DELETE` sobre `Venta` protege el historial comercial y evita el borrado en cascada de `DetalleVenta`, algo que ni los `CHECK` ni las FK del modelo impedían.
- Las restricciones se evalúan antes que los triggers `AFTER`, así que solo se auditan las operaciones que se completaron.
- La auditoría funciona junto con las ventas de los otros temas: el stock descontado por `sp_RegistrarVenta` queda registrado, y un `ROLLBACK` deshace también la auditoría.
- Limitaciones: la auditoría guarda solo el valor anterior (el nuevo está en la tabla original, y la secuencia se reconstruye con las filas sucesivas). Además, un usuario con permiso `ALTER` puede deshabilitar o borrar los triggers, por lo que conviene combinarlos con la seguridad por roles del tema de permisos.
