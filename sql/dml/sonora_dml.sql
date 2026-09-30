INSERT INTO Marca (nombre_marca) VALUES
('Yamaha'),('Fender'),('Gibson'),('Roland'),('Ibanez'),('Casio'),('Pearl'),('Korg');
 
INSERT INTO Categoria (nombre_categoria) VALUES
('Guitarras'),('Bajos'),('Teclados'),('Baterías'),('Vientos'),('Cuerdas frotadas'),('Percusión'),('Accesorios');
 
INSERT INTO MetodoPago (nombre_metodo) VALUES
('Efectivo'),('Tarjeta de débito'),('Tarjeta de crédito'),('Transferencia'),
('Mercado Pago'),('QR'),('Cheque'),('Débito automático');
 
INSERT INTO Instrumento (nombre_instrumento, precio, stock, id_categoria, id_marca) VALUES
('Guitarra Stratocaster',        850000.00, 5, 1, 2),
('Guitarra Les Paul Standard',  1200000.00, 3, 1, 3),
('Bajo Jazz Bass',               780000.00, 2, 2, 2),
('Teclado PSR-E373',             420000.00, 6, 3, 1),
('Piano digital P-45',           690000.00, 4, 3, 1),
('Batería acústica Export',      950000.00, 2, 4, 7),
('Saxo alto YAS-280',           1100000.00, 0, 5, 1),
('Violín 4/4 estudiante',        310000.00, 7, 6, 1),
('Guitarra eléctrica RG',        640000.00, 3, 1, 5),
('Sintetizador Juno',           1500000.00, 2, 3, 4);
 
INSERT INTO UnidadInstrumento (estado, cod_instrumento) VALUES
('Disponible',1),('Alquilada',1),('Disponible',3),('Disponible',4),('Alquilada',5),
('Disponible',6),('En mantenimiento',8),('Disponible',2),('Disponible',9),('Disponible',10);
 
INSERT INTO Cliente (dni, nombre, apellido, num_telefono) VALUES
(40111222,'Lucas','Fernández','3794111111'),
(38222333,'María','Gómez','3794222222'),
(42333444,'Julián','Ramírez','3794333333'),
(36444555,'Sofía','Benítez','3794444444'),
(41555666,'Mateo','Acosta','3794555555'),
(39666777,'Valentina','Romero','3794666666'),
(43777888,'Tomás','Silva','3794777777'),
(37888999,'Camila','Díaz','3794888888'),
(44999000,'Agustín','López','3794999999'),
(35123456,'Lucía','Herrera','3794101010');
 
-- rol corregido: 'V' -> 'VENDEDOR', 'T' -> 'TECNICO'
INSERT INTO Empleado (dni_empleado, nombre, apellido, num_telefono, rol) VALUES
(30000001,'Carlos','Méndez','3795000001','VENDEDOR'),
(30000002,'Laura','Paz','3795000002','VENDEDOR'),
(30000003,'Diego','Ortiz','3795000003','VENDEDOR'),
(30000004,'Ana','Vega','3795000004','VENDEDOR'),
(30000005,'Martín','Ríos','3795000005','VENDEDOR'),
(30000006,'Paula','Cabrera','3795000006','VENDEDOR'),
(30000007,'Nicolás','Soto','3795000007','VENDEDOR'),
(30000008,'Florencia','Luna','3795000008','VENDEDOR'),
(30000009,'Javier','Molina','3795000009','TECNICO'),
(30000010,'Rocío','Castro','3795000010','TECNICO'),
(30000011,'Bruno','Peralta','3795000011','TECNICO'),
(30000012,'Elena','Suárez','3795000012','TECNICO'),
(30000013,'Hugo','Navarro','3795000013','TECNICO'),
(30000014,'Marta','Ibarra','3795000014','TECNICO'),
(30000015,'Sergio','Duarte','3795000015','TECNICO'),
(30000016,'Julia','Medina','3795000016','TECNICO');
 
INSERT INTO Vendedor (dni_empleado) VALUES
(30000001),(30000002),(30000003),(30000004),(30000005),(30000006),(30000007),(30000008);
 
INSERT INTO Tecnico (dni_empleado) VALUES
(30000009),(30000010),(30000011),(30000012),(30000013),(30000014),(30000015),(30000016);
 
INSERT INTO Venta (fecha_venta, id_cliente, dni_vendedor, id_metodo_pago) VALUES
('20260105 10:30',1,30000001,1),
('20260112 16:45',2,30000002,3),
('20260120 11:10',3,30000003,2),
('20260203 18:20',4,30000001,4),
('20260214 12:00',5,30000004,5),
('20260301 09:40',6,30000005,6),
('20260318 17:15',7,30000002,3),
('20260405 15:30',8,30000006,1),
('20260422 13:05',9,30000007,2),
('20260510 19:00',10,30000008,4);
 
INSERT INTO DetalleVenta (id_venta, cod_instrumento, cantidad, precio_unitario) VALUES
(1,1,1,850000.00),
(2,4,2,420000.00),
(3,9,1,640000.00),
(4,2,1,1200000.00),
(5,5,1,690000.00),
(6,8,2,310000.00),
(7,3,1,780000.00),
(8,6,1,950000.00),
(9,10,1,1500000.00),
(10,1,1,850000.00),
(10,4,1,420000.00);
 
INSERT INTO Alquiler (fecha_entrega, seguro_efectivo, id_cliente, dni_vendedor) VALUES
('20260110',50000.00,1,30000001),
('20260125',40000.00,2,30000002),
('20260207',30000.00,3,30000003),
('20260220',60000.00,4,30000004),
('20260310',45000.00,5,30000005),
('20260328',80000.00,6,30000006),
('20260915',50000.00,7,30000007),
('20260925',70000.00,8,30000008);
 
INSERT INTO DetalleAlquiler (id_alquiler, id_unidad, fecha_devolucion) VALUES
(1,1,'20260117'),
(2,3,'20260201'),
(3,4,'20260214'),
(4,6,'20260227'),
(5,9,'20260317'),
(6,10,'20260404'),
(7,2,NULL),
(8,5,NULL);
 
INSERT INTO InstrumentoCliente (descripcion, marca, modelo, id_cliente) VALUES
('Guitarra acústica con tapa rajada','Yamaha','F310',1),
('Bajo eléctrico sin sonido','Fender','Precision',2),
('Teclado con teclas trabadas','Casio','CT-S300',3),
('Guitarra eléctrica con ruido en el potenciómetro','Ibanez','RG421',4),
('Violín con puente desplazado','Stentor','Student I',5),
('Batería con parche roto','Pearl','Export',6),
('Saxo con zapatillas gastadas','Yamaha','YAS-26',7),
('Sintetizador que no enciende','Korg','Minilogue',8);
 
INSERT INTO OrdenReparacion (fecha_ingreso, tipo_reparacion, tiempo_estimado, id_instrumento_cliente, dni_tecnico) VALUES
('20260108','Reparación de tapa','20260120',1,30000009),
('20260115','Revisión de electrónica','20260122',2,30000010),
('20260201','Limpieza y ajuste de teclas','20260210',3,30000011),
('20260216','Cambio de potenciómetro','20260220',4,30000012),
('20260305','Ajuste de puente y afinación','20260308',5,30000013),
('20260320','Cambio de parche','20260325',6,30000014),
('20260410','Cambio de zapatillas','20260420',7,30000015),
('20260505','Diagnóstico de fuente de alimentación','20260515',8,30000016),
('20260601','Reparación de tapa (reincidencia)','20260612',1,30000009),
('20260710','Ajuste de electrónica','20260715',2,30000010);

-- verifi

SELECT * FROM OrdenReparacion;
SELECT * FROM DetalleAlquiler;
SELECT * FROM DetalleVenta;
SELECT * FROM Alquiler;
SELECT * FROM Venta;
SELECT * FROM InstrumentoCliente;
SELECT * FROM Vendedor;
SELECT * FROM Tecnico;
SELECT * FROM Empleado;
SELECT * FROM UnidadInstrumento;
SELECT * FROM Instrumento;
SELECT * FROM Cliente;
SELECT * FROM MetodoPago;
SELECT * FROM Categoria;
SELECT * FROM Marca;
