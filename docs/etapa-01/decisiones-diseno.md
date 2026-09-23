# Decisiones de diseño (análisis del proyecto)


Al pensar el proyecto, Arrancamos por los alquileres y lo primero que decidimos fue que el seguro que deja el cliente sea simplemente un monto de dinero en garantía, sin crear ninguna entidad ni objeto aparte para representarlo, porque no tiene atributos ni comportamiento propio más allá de ese valor.

También definimos que el negocio funcione en una única ubicación física, sin sucursales, para no meternos en una complejidad que no le suma nada al proyecto en esta etapa.

Otra decisión fue permitir que un instrumento pueda estar cargado en el catálogo con stock en cero, porque tiene sentido que la empresa pueda dar de alta un modelo nuevo antes de que lleguen las unidades físicas.

Para el servicio técnico, decidimos que solo se registran instrumentos que son propiedad del propio cliente que los trae a reparar, y no de terceros, para mantener ese proceso simple.

Sobre los métodos de pago, decidimos manejarlos como un catálogo abierto (efectivo, tarjeta, transferencia, etc.) que la empresa pueda ir ampliando, en vez de dejarlos fijos, porque es información que puede cambiar con el tiempo.

También discutimos si un empleado podía ser vendedor y técnico a la vez, y decidimos que no, que cada uno tiene un solo rol fijo (RN13). Por eso en la RN12 dejamos en claro que un vendedor no puede hacerse cargo de una reparación: directamente no puede ser técnico.

En cuanto al alcance, decidimos dejar afuera la facturación electrónica porque el sistema es para uso interno del negocio en esta primera versión, no descartamos el comercio electronico en un futuro

Por último, nos dimos cuenta de que la regla de que una unidad de instrumento no puede estar en más de un alquiler activo a la vez (RN09) no se puede resolver dibujando el diagrama, porque depende del tiempo (si el alquiler está activo o no en este momento). Decidimos que esto se controla a nivel de la aplicación, usando el atributo de estado de la unidad, y no como una restricción estructural del modelo.
