# Restricciones e integridad - Sonora Instrumentos

Resumen de las restricciones definidas en el script DDL (`implementacion.md`) y cómo se relacionan con las reglas de negocio del proyecto.

## 1. Claves primarias

| Tabla | Clave primaria | Tipo |
|---|---|---|
| `Marca` | `id_marca` | IDENTITY |
| `Categoria` | `id_categoria` | IDENTITY |
| `MetodoPago` | `id_metodo_pago` | IDENTITY |
| `Instrumento` | `cod_instrumento` | IDENTITY |
| `UnidadInstrumento` | `id_unidad` | IDENTITY |
| `Cliente` | `id_cliente` | IDENTITY |
| `Empleado` | `dni_empleado` | DNI |
| `Vendedor` | `dni_empleado` | DNI (hereda de `Empleado`) |
| `Tecnico` | `dni_empleado` | DNI (hereda de `Empleado`) |
| `Venta` | `id_venta` | IDENTITY |
| `DetalleVenta` | (`id_venta`, `cod_instrumento`) | Compuesta |
| `Alquiler` | `id_alquiler` | IDENTITY |
| `DetalleAlquiler` | (`id_alquiler`, `id_unidad`) | Compuesta |
| `InstrumentoCliente` | `id_instrumento_cliente` | IDENTITY |
| `OrdenReparacion` | `id_reparacion` | IDENTITY |

## 2. Claves foráneas y reglas de borrado/modificación

| Tabla origen | Columna | Referencia | ON DELETE | ON UPDATE |
|---|---|---|---|---|
| `Instrumento` | `id_categoria` | `Categoria` | NO ACTION | CASCADE |
| `Instrumento` | `id_marca` | `Marca` | NO ACTION | CASCADE |
| `UnidadInstrumento` | `cod_instrumento` | `Instrumento` | NO ACTION | CASCADE |
| `Vendedor` | (`dni_empleado`, `rol`) | `Empleado` | CASCADE | NO ACTION |
| `Tecnico` | (`dni_empleado`, `rol`) | `Empleado` | CASCADE | NO ACTION |
| `Venta` | `id_cliente` | `Cliente` | NO ACTION | CASCADE |
| `Venta` | `dni_vendedor` | `Vendedor` | NO ACTION | NO ACTION |
| `Venta` | `id_metodo_pago` | `MetodoPago` | NO ACTION | CASCADE |
| `DetalleVenta` | `id_venta` | `Venta` | CASCADE | CASCADE |
| `DetalleVenta` | `cod_instrumento` | `Instrumento` | NO ACTION | NO ACTION |
| `Alquiler` | `id_cliente` | `Cliente` | NO ACTION | CASCADE |
| `Alquiler` | `dni_vendedor` | `Vendedor` | NO ACTION | NO ACTION |
| `DetalleAlquiler` | `id_alquiler` | `Alquiler` | CASCADE | CASCADE |
| `DetalleAlquiler` | `id_unidad` | `UnidadInstrumento` | NO ACTION | NO ACTION |
| `InstrumentoCliente` | `id_cliente` | `Cliente` | NO ACTION | CASCADE |
| `OrdenReparacion` | `id_instrumento_cliente` | `InstrumentoCliente` | NO ACTION | CASCADE |
| `OrdenReparacion` | `dni_tecnico` | `Tecnico` | NO ACTION | NO ACTION |

Usamos NO ACTION en la mayoría de los borrados para no perder el historial de clientes, instrumentos y empleados. CASCADE aparece en las tablas de detalle (`DetalleVenta`, `DetalleAlquiler`), que no tienen razón de existir sin su cabecera, y también en `Vendedor`/`Tecnico`: si se borra el empleado que los sostiene, el subtipo tiene que desaparecer con él.

Una aclaración que no está en el script pero conviene dejar escrita: los `ON UPDATE CASCADE` hacia `Categoria`, `Marca`, `Cliente`, `MetodoPago`, `Venta`, `Alquiler` e `InstrumentoCliente` en la práctica nunca se van a disparar, porque esas claves primarias son `IDENTITY` y SQL Server no permite actualizar una columna `IDENTITY`. Quedaron puestas por prolijidad y consistencia con el resto de las FK, pero es código que nunca se ejecuta.

## 3. Restricciones UNIQUE

| Tabla | Columna(s) | Motivo |
|---|---|---|
| `Cliente` | `dni` | RN01: DNI único |
| `Marca` | `nombre_marca` | Evitar marcas duplicadas |
| `Categoria` | `nombre_categoria` | Evitar categorías duplicadas |
| `MetodoPago` | `nombre_metodo` | Evitar métodos duplicados |
| `Empleado` | (`dni_empleado`, `rol`) | Permite que `Vendedor`/`Tecnico` fijen el rol (RN13) |

## 4. Restricciones CHECK

| Tabla | Regla |
|---|---|
| `Instrumento` | `precio > 0` y `stock >= 0` |
| `UnidadInstrumento` | `estado` en (`Disponible`, `Alquilada`, `En mantenimiento`) |
| `Empleado` | `rol` en (`VENDEDOR`, `TECNICO`) |
| `Vendedor` | `rol = 'VENDEDOR'` |
| `Tecnico` | `rol = 'TECNICO'` |
| `DetalleVenta` | `cantidad > 0` y `precio_unitario > 0` |
| `Alquiler` | `seguro_efectivo >= 0` |
| `OrdenReparacion` | `tiempo_estimado >= fecha_ingreso` |

## 5. NOT NULL y valores por defecto

Todas las columnas son `NOT NULL`, salvo `DetalleAlquiler.fecha_devolucion`, que queda en `NULL` mientras el alquiler sigue activo.

Valores por defecto: `Instrumento.stock = 0`, `UnidadInstrumento.estado = 'Disponible'`, `Venta.fecha_venta = GETDATE()`, `Vendedor.rol = 'VENDEDOR'`, `Tecnico.rol = 'TECNICO'`.

## 6. Cobertura de las reglas de negocio

| Regla | Cómo se cumple |
|---|---|
| RN01 DNI único del cliente | `UNIQUE` en `Cliente.dni` |
| RN02 Un instrumento, una categoría | FK `Instrumento.id_categoria` (`NOT NULL`) |
| RN03 Un instrumento, una marca | FK `Instrumento.id_marca` (`NOT NULL`) |
| RN04 Venta con un cliente y un vendedor | FK `NOT NULL` a `Cliente` y a `Vendedor` |
| RN05 Venta con varios instrumentos; cantidad y precio unitario | `DetalleVenta` con PK compuesta y precio histórico |
| RN06 Un método de pago por venta | FK `Venta.id_metodo_pago` (`NOT NULL`) |
| RN07 Una unidad pertenece a un instrumento | FK `UnidadInstrumento.cod_instrumento` (`NOT NULL`) |
| RN08 Alquiler con un cliente y un vendedor | FK `NOT NULL` a `Cliente` y a `Vendedor` |
| RN09 Unidad sin alquiler activo doble | Queda a cargo de la aplicación; `UnidadInstrumento.estado` ayuda pero no lo garantiza por sí solo |
| RN10 Instrumento reparado pertenece a un cliente | FK `InstrumentoCliente.id_cliente` (`NOT NULL`) |
| RN11 Varias órdenes por instrumento | FK `OrdenReparacion.id_instrumento_cliente` |
| RN12 Reparación atendida por un técnico | FK a `Tecnico`; un vendedor no puede figurar ahí |
| RN13 Un único rol por empleado | `Empleado.rol` + FK compuesta + `CHECK` de rol fijo |
