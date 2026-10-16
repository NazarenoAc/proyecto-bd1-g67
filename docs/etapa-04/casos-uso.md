# Casos de uso

Las tres consultas responden a cosas que le van a pasar a Sonora Instrumentos en el día a día. Todas están en `sql/consultas/` y se probaron con la base cargada con el DDL y el DML de la etapa 3.

## Darle el comprobante a un cliente
Cuando alguien compra, el vendedor tiene que poder mostrarle qué se llevó, a qué precio y cuánto es el total. Eso lo resuelve el [comprobante de venta](comprobante-venta.md). Para otra venta alcanza con cambiar el número en el WHERE.

## Ver cuánto vendió cada vendedor
Para comparar vendedores hace falta saber cuántas ventas hizo cada uno en un período y por qué monto. Eso lo resuelve el [informe de ventas](informe-venta.md). Para otro período se cambian las fechas del WHERE, y también los textos `desde` y `hasta` de la salida.

## Saber qué instrumentos caros se están vendiendo
Para decidir qué comprar o promocionar sirve saber cuáles de los instrumentos más caros que el promedio ya tuvieron ventas. Eso lo resuelve la [consulta avanzada](consulta-avanzada.md).
