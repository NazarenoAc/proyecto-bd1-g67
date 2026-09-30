# Reglas de negocio

- RN01: Cada cliente debe registrarse con un DNI único.
- RN02: Cada instrumento del catálogo pertenece a una única categoría; una categoría puede tener varios instrumentos.
- RN03: Cada instrumento del catálogo pertenece a una única marca; una marca puede tener varios instrumentos.
- RN04: Cada venta corresponde a un único cliente y es atendida por un único vendedor. Un cliente y un vendedor pueden participar en varias ventas.
- RN05: Una venta puede incluir uno o varios instrumentos, y un mismo instrumento puede estar en varias ventas. De cada instrumento vendido se registra cantidad y precio unitario de esa operación.
- RN06:Cada venta se realiza con un único método de pago. Un método de pago puede usarse en varias ventas.
- RN07: Cada unidad de instrumento corresponde a un único instrumento del catálogo; un instrumento puede tener cero, una o varias unidades.
- RN08: Cada alquiler corresponde a un único cliente, un cliente puede alquilar varias unidades de instrumento, y es gestionado por un único vendedor. Un cliente y un vendedor pueden participar en varios alquileres.
- RN09: Una unidad de instrumento no puede estar en más de un alquiler activo a la vez.
- RN10: Cada instrumento llevado a reparación pertenece a un único cliente; un cliente puede tener varios instrumentos en reparación.
- RN11: Un instrumento del cliente puede tener varias órdenes de reparación a lo largo del tiempo; cada orden corresponde a un único instrumento.
- RN12: Cada orden de reparación es atendida por un único técnico; un técnico puede atender varias órdenes. Un empleado con rol de vendedor no puede ser responsable de una reparación.
- RN13: Cada empleado tiene un único rol, vendedor o técnico, no los dos a la vez.
