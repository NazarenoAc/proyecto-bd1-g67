USE master;
GO
IF DB_ID('SonoraInstrumentos') IS NOT NULL
BEGIN
    ALTER DATABASE SonoraInstrumentos SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SonoraInstrumentos;
END
GO
CREATE DATABASE SonoraInstrumentos;
GO
USE SonoraInstrumentos;
GO

-- ===== Catálogos =====
CREATE TABLE Marca (
    id_marca     INT IDENTITY(1,1) CONSTRAINT PK_Marca PRIMARY KEY,
    nombre_marca VARCHAR(50) NOT NULL CONSTRAINT UQ_Marca_nombre UNIQUE
);

CREATE TABLE Categoria (
    id_categoria     INT IDENTITY(1,1) CONSTRAINT PK_Categoria PRIMARY KEY,
    nombre_categoria VARCHAR(50) NOT NULL CONSTRAINT UQ_Categoria_nombre UNIQUE
);

CREATE TABLE MetodoPago (
    id_metodo_pago INT IDENTITY(1,1) CONSTRAINT PK_MetodoPago PRIMARY KEY,
    nombre_metodo  VARCHAR(50) NOT NULL CONSTRAINT UQ_MetodoPago_nombre UNIQUE
);

CREATE TABLE Instrumento (
    cod_instrumento    INT IDENTITY(1,1) CONSTRAINT PK_Instrumento PRIMARY KEY,
    nombre_instrumento VARCHAR(100) NOT NULL,
    precio             DECIMAL(12,2) NOT NULL CONSTRAINT CK_Instrumento_precio CHECK (precio > 0),
    stock              INT NOT NULL CONSTRAINT DF_Instrumento_stock DEFAULT 0
                           CONSTRAINT CK_Instrumento_stock CHECK (stock >= 0),
    id_categoria       INT NOT NULL,
    id_marca           INT NOT NULL,
    CONSTRAINT FK_Instrumento_Categoria FOREIGN KEY (id_categoria)
        REFERENCES Categoria(id_categoria) ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT FK_Instrumento_Marca FOREIGN KEY (id_marca)
        REFERENCES Marca(id_marca) ON DELETE NO ACTION ON UPDATE CASCADE
);

CREATE TABLE UnidadInstrumento (
    id_unidad       INT IDENTITY(1,1) CONSTRAINT PK_UnidadInstrumento PRIMARY KEY,
    estado          VARCHAR(20) NOT NULL CONSTRAINT DF_Unidad_estado DEFAULT 'Disponible'
                        CONSTRAINT CK_Unidad_estado CHECK (estado IN ('Disponible','Alquilada','En mantenimiento')),
    cod_instrumento INT NOT NULL,
    CONSTRAINT FK_Unidad_Instrumento FOREIGN KEY (cod_instrumento)
        REFERENCES Instrumento(cod_instrumento) ON DELETE NO ACTION ON UPDATE CASCADE
);

-- ===== Personas =====
CREATE TABLE Cliente (
    id_cliente   INT IDENTITY(1,1) CONSTRAINT PK_Cliente PRIMARY KEY,
    dni          INT NOT NULL CONSTRAINT UQ_Cliente_dni UNIQUE,              -- RN01
    nombre       VARCHAR(50) NOT NULL,
    apellido     VARCHAR(50) NOT NULL,
    num_telefono VARCHAR(20) NOT NULL
);

-- RN13: cada empleado tiene un único rol (V = vendedor, T = técnico)
CREATE TABLE Empleado (
    dni_empleado INT CONSTRAINT PK_Empleado PRIMARY KEY,
    nombre       VARCHAR(50) NOT NULL,
    apellido     VARCHAR(50) NOT NULL,
    num_telefono VARCHAR(20) NOT NULL,
    rol          CHAR(1) NOT NULL CONSTRAINT CK_Empleado_rol CHECK (rol IN ('V','T')),
    CONSTRAINT UQ_Empleado_dni_rol UNIQUE (dni_empleado, rol)
);

CREATE TABLE Vendedor (
    dni_empleado INT CONSTRAINT PK_Vendedor PRIMARY KEY,
    rol          CHAR(1) NOT NULL CONSTRAINT DF_Vendedor_rol DEFAULT 'V'
                     CONSTRAINT CK_Vendedor_rol CHECK (rol = 'V'),
    CONSTRAINT FK_Vendedor_Empleado FOREIGN KEY (dni_empleado, rol)
        REFERENCES Empleado(dni_empleado, rol) ON DELETE CASCADE ON UPDATE NO ACTION
);

CREATE TABLE Tecnico (
    dni_empleado INT CONSTRAINT PK_Tecnico PRIMARY KEY,
    rol          CHAR(1) NOT NULL CONSTRAINT DF_Tecnico_rol DEFAULT 'T'
                     CONSTRAINT CK_Tecnico_rol CHECK (rol = 'T'),
    CONSTRAINT FK_Tecnico_Empleado FOREIGN KEY (dni_empleado, rol)
        REFERENCES Empleado(dni_empleado, rol) ON DELETE CASCADE ON UPDATE NO ACTION
);

-- ===== Ventas =====
CREATE TABLE Venta (
    id_venta       INT IDENTITY(1,1) CONSTRAINT PK_Venta PRIMARY KEY,
    fecha_venta    DATETIME NOT NULL CONSTRAINT DF_Venta_fecha DEFAULT GETDATE(),
    id_cliente     INT NOT NULL,
    dni_vendedor   INT NOT NULL,
    id_metodo_pago INT NOT NULL,
    CONSTRAINT FK_Venta_Cliente FOREIGN KEY (id_cliente)
        REFERENCES Cliente(id_cliente) ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT FK_Venta_Vendedor FOREIGN KEY (dni_vendedor)
        REFERENCES Vendedor(dni_empleado) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Venta_MetodoPago FOREIGN KEY (id_metodo_pago)
        REFERENCES MetodoPago(id_metodo_pago) ON DELETE NO ACTION ON UPDATE CASCADE
);

CREATE TABLE DetalleVenta (
    id_venta        INT NOT NULL,
    cod_instrumento INT NOT NULL,
    cantidad        INT NOT NULL CONSTRAINT CK_DetVenta_cantidad CHECK (cantidad > 0),
    precio_unitario DECIMAL(12,2) NOT NULL CONSTRAINT CK_DetVenta_precio CHECK (precio_unitario > 0),
    CONSTRAINT PK_DetalleVenta PRIMARY KEY (id_venta, cod_instrumento),
    CONSTRAINT FK_DetVenta_Venta FOREIGN KEY (id_venta)
        REFERENCES Venta(id_venta) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_DetVenta_Instrumento FOREIGN KEY (cod_instrumento)
        REFERENCES Instrumento(cod_instrumento) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- ===== Alquileres =====
CREATE TABLE Alquiler (
    id_alquiler     INT IDENTITY(1,1) CONSTRAINT PK_Alquiler PRIMARY KEY,
    fecha_entrega   DATE NOT NULL,
    seguro_efectivo DECIMAL(12,2) NOT NULL CONSTRAINT CK_Alquiler_seguro CHECK (seguro_efectivo >= 0),
    id_cliente      INT NOT NULL,                                            -- RN08
    dni_vendedor    INT NOT NULL,
    CONSTRAINT FK_Alquiler_Cliente FOREIGN KEY (id_cliente)
        REFERENCES Cliente(id_cliente) ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT FK_Alquiler_Vendedor FOREIGN KEY (dni_vendedor)
        REFERENCES Vendedor(dni_empleado) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE TABLE DetalleAlquiler (
    id_alquiler      INT NOT NULL,
    id_unidad        INT NOT NULL,
    fecha_devolucion DATE NULL,                                              -- NULL = alquiler activo
    CONSTRAINT PK_DetalleAlquiler PRIMARY KEY (id_alquiler, id_unidad),
    CONSTRAINT FK_DetAlq_Alquiler FOREIGN KEY (id_alquiler)
        REFERENCES Alquiler(id_alquiler) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT FK_DetAlq_Unidad FOREIGN KEY (id_unidad)
        REFERENCES UnidadInstrumento(id_unidad) ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- ===== Servicio técnico =====
CREATE TABLE InstrumentoCliente (
    id_instrumento_cliente INT IDENTITY(1,1) CONSTRAINT PK_InstrumentoCliente PRIMARY KEY,
    descripcion VARCHAR(150) NOT NULL,
    marca       VARCHAR(50) NOT NULL,
    modelo      VARCHAR(50) NOT NULL,
    id_cliente  INT NOT NULL,
    CONSTRAINT FK_InstCli_Cliente FOREIGN KEY (id_cliente)
        REFERENCES Cliente(id_cliente) ON DELETE NO ACTION ON UPDATE CASCADE
);

CREATE TABLE OrdenReparacion (
    id_reparacion          INT IDENTITY(1,1) CONSTRAINT PK_OrdenReparacion PRIMARY KEY,
    fecha_ingreso          DATE NOT NULL,
    tipo_reparacion        VARCHAR(100) NOT NULL,
    tiempo_estimado        DATE NOT NULL,
    id_instrumento_cliente INT NOT NULL,
    dni_tecnico            INT NOT NULL,
    CONSTRAINT CK_Orden_fechas CHECK (tiempo_estimado >= fecha_ingreso),
    CONSTRAINT FK_Orden_InstCli FOREIGN KEY (id_instrumento_cliente)
        REFERENCES InstrumentoCliente(id_instrumento_cliente) ON DELETE NO ACTION ON UPDATE CASCADE,
    CONSTRAINT FK_Orden_Tecnico FOREIGN KEY (dni_tecnico)
        REFERENCES Tecnico(dni_empleado) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO
