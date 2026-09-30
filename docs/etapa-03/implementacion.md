# Implementación física - Sonora Instrumentos


 1. Resumen

La base implementa el modelo relacional normalizado (hasta 3FN) de Sonora Instrumentos: 15 tablas que cubren catálogo, personas, ventas, alquileres y servicio técnico.

| Módulo | Tablas |
|---|---|
| Catálogo | `Marca`, `Categoria`, `Instrumento`, `UnidadInstrumento` |
| Personas | `Cliente`, `Empleado`, `Vendedor`, `Tecnico` |
| Ventas | `MetodoPago`, `Venta`, `DetalleVenta` |
| Alquileres | `Alquiler`, `DetalleAlquiler` |
| Servicio técnico | `InstrumentoCliente`, `OrdenReparacion` |

## 2. Decisiones de implementación

- **DNI del cliente (RN01):** se agregó `dni` a `Cliente` con restricción `UNIQUE`. `id_cliente` es la clave primaria sustituta.
- **Alquiler (RN08):** cada alquiler pertenece a un único cliente, por lo que se modeló con la FK `id_cliente` en `Alquiler`. La tabla `Solicita` del modelo relacional resulta redundante y no se implementa.
- **Rol único del empleado (RN12 / RN13):** `Empleado` tiene la columna `rol` (`VENDEDOR` o `TECNICO`) y `UNIQUE (dni_empleado, rol)`. `Vendedor` y `Tecnico` referencian esa pareja con el rol fijado por `CHECK`, por lo que un empleado no puede ser vendedor y técnico a la vez.
- **Atomicidad (1FN):** nombre y apellido se guardan en columnas separadas.
- **Teléfonos** como `VARCHAR`, para conservar ceros y prefijos.
- **Stock en cero** permitido (`CHECK (stock >= 0)`), para dar de alta un modelo antes de recibir unidades.
- **RN09** (una unidad no puede estar en dos alquileres activos a la vez) se controla a nivel de aplicación mediante `UnidadInstrumento.estado`. En `DetalleAlquiler`, `fecha_devolucion = NULL` indica alquiler activo.
- **Historial de precios (RN05):** `DetalleVenta.precio_unitario` guarda el precio al momento de la venta.
- **Facturación electrónica** fuera del alcance de esta versión.

## 3. Cómo ejecutar

1. Abrir SQL Server Management Studio y conectarse a `localhost\SQLEXPRESS` (autenticación de Windows, marcar "Certificado de servidor de confianza").
2. Ejecutar el script DDL (sección 4). Crea la base `SonoraInstrumentos`.
3. Ejecutar el script DML (sección 5) **una sola vez**. Volver a ejecutarlo duplica registros en tablas sin clave única natural.

## 4. Script DDL

proyecto-bd1-equipo-67/sql/ddl/SonoraInstrumentosDDL.sql

## 5. Script DML
proyecto-bd1-equipo-67/sql/dml/sonora_dml.sql


```
