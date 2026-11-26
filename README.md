# Proyecto Reserva Taller

Aplicación para gestionar las reservas (citas) de un taller mecánico.

## Base de datos (provisional)

El esquema está en [`database/schema.sql`](database/schema.sql) (MySQL 8 / MariaDB 10.5+).

```bash
mysql -u root -p < database/schema.sql
```

### Tablas principales

| Tabla | Descripción |
|---|---|
| `usuarios` | Cuentas de acceso y rol (admin, recepción, mecánico, cliente) |
| `clientes` | Datos de los clientes |
| `vehiculos` | Vehículos de cada cliente |
| `mecanicos` | Personal del taller |
| `puestos` | Elevadores / boxes reservables |
| `servicios` | Catálogo de servicios con duración y precio |
| `horarios_taller` | Horario de apertura por día de la semana |
| `dias_cierre` | Festivos y cierres |
| `reservas` | Citas: cliente, vehículo, mecánico, puesto, franja y estado |
| `reserva_servicios` | Servicios incluidos en cada reserva |
| `reserva_historial` | Historial de cambios de estado |

Incluye la vista `v_agenda`.
