/*Consulta avanzada
CONSULTA AVANZADA (instrumentos sobre el precio promedio que ya se vendieron)
Une Instrumento, Categoria, Marca y DetalleVenta y filtra con una subconsulta
(AVG) los instrumentos cuyo precio supera el promedio del catalogo. Para cada
uno muestra categoria, marca y unidades vendidas. Los instrumentos que nunca se
vendieron no aparecen porque el JOIN con DetalleVenta los deja afuera. */
SELECT i.cod_instrumento, i.nombre_instrumento,
       cat.nombre_categoria, m.nombre_marca, i.precio,
       SUM(dv.cantidad) AS unidades_vendidas
FROM Instrumento i
JOIN Categoria cat ON cat.id_categoria = i.id_categoria
JOIN Marca m ON m.id_marca = i.id_marca
JOIN DetalleVenta dv  ON dv.cod_instrumento = i.cod_instrumento
WHERE i.precio > (SELECT AVG(precio) FROM Instrumento)
GROUP BY i.cod_instrumento, i.nombre_instrumento, cat.nombre_categoria, m.nombre_marca, i.precio
ORDER BY unidades_vendidas DESC, i.precio DESC; 
