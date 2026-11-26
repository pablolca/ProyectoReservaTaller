-- =====================================================================
--  Proyecto Reserva Taller - Base de datos provisional
--  Motor: MySQL 8.x / MariaDB 10.5+
--  Codificación: utf8mb4
-- =====================================================================

DROP DATABASE IF EXISTS reserva_taller;
CREATE DATABASE reserva_taller CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE reserva_taller;

-- ---------------------------------------------------------------------
-- Usuarios de la aplicación (admin, recepción, mecánicos, clientes)
-- ---------------------------------------------------------------------
CREATE TABLE usuarios (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email           VARCHAR(150) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL,
    rol             ENUM('ADMIN','RECEPCION','MECANICO','CLIENTE') NOT NULL DEFAULT 'CLIENTE',
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Clientes
-- ---------------------------------------------------------------------
CREATE TABLE clientes (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id      INT UNSIGNED NULL UNIQUE,
    nombre          VARCHAR(100) NOT NULL,
    apellidos       VARCHAR(150) NOT NULL,
    dni_nif         VARCHAR(20)  NULL UNIQUE,
    telefono        VARCHAR(20)  NOT NULL,
    email           VARCHAR(150) NULL,
    direccion       VARCHAR(255) NULL,
    notas           TEXT NULL,
    creado_en       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_clientes_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Vehículos de los clientes
-- ---------------------------------------------------------------------
CREATE TABLE vehiculos (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cliente_id      INT UNSIGNED NOT NULL,
    matricula       VARCHAR(15)  NOT NULL UNIQUE,
    marca           VARCHAR(50)  NOT NULL,
    modelo          VARCHAR(50)  NOT NULL,
    anio            SMALLINT UNSIGNED NULL,
    bastidor_vin    VARCHAR(17)  NULL UNIQUE,
    combustible     ENUM('GASOLINA','DIESEL','HIBRIDO','ELECTRICO','GLP','OTRO') NULL,
    kilometraje     INT UNSIGNED NULL,
    creado_en       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_vehiculos_cliente FOREIGN KEY (cliente_id)
        REFERENCES clientes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Mecánicos / empleados del taller
-- ---------------------------------------------------------------------
CREATE TABLE mecanicos (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id      INT UNSIGNED NULL UNIQUE,
    nombre          VARCHAR(100) NOT NULL,
    apellidos       VARCHAR(150) NOT NULL,
    especialidad    VARCHAR(100) NULL,
    telefono        VARCHAR(20)  NULL,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_mecanicos_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Puestos / elevadores del taller (recurso físico reservable)
-- ---------------------------------------------------------------------
CREATE TABLE puestos (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL UNIQUE,
    descripcion     VARCHAR(255) NULL,
    activo          BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Catálogo de servicios
-- ---------------------------------------------------------------------
CREATE TABLE servicios (
    id                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre              VARCHAR(100) NOT NULL UNIQUE,
    descripcion         TEXT NULL,
    duracion_minutos    SMALLINT UNSIGNED NOT NULL,
    precio_base         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    activo              BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Horario de apertura del taller (por día de la semana)
-- dia_semana: 1 = lunes ... 7 = domingo
-- ---------------------------------------------------------------------
CREATE TABLE horarios_taller (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    dia_semana      TINYINT UNSIGNED NOT NULL,
    hora_apertura   TIME NOT NULL,
    hora_cierre     TIME NOT NULL,
    CONSTRAINT chk_dia_semana CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT chk_horas CHECK (hora_cierre > hora_apertura)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Días de cierre (festivos, vacaciones)
-- ---------------------------------------------------------------------
CREATE TABLE dias_cierre (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fecha           DATE NOT NULL UNIQUE,
    motivo          VARCHAR(150) NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Reservas
-- ---------------------------------------------------------------------
CREATE TABLE reservas (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo          VARCHAR(20) NOT NULL UNIQUE,
    cliente_id      INT UNSIGNED NOT NULL,
    vehiculo_id     INT UNSIGNED NOT NULL,
    mecanico_id     INT UNSIGNED NULL,
    puesto_id       INT UNSIGNED NULL,
    fecha_inicio    DATETIME NOT NULL,
    fecha_fin       DATETIME NOT NULL,
    estado          ENUM('PENDIENTE','CONFIRMADA','EN_CURSO','FINALIZADA','CANCELADA','NO_PRESENTADO')
                    NOT NULL DEFAULT 'PENDIENTE',
    canal           ENUM('WEB','TELEFONO','PRESENCIAL','APP') NOT NULL DEFAULT 'WEB',
    observaciones   TEXT NULL,
    importe_estimado DECIMAL(10,2) NULL,
    creado_en       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_reservas_cliente  FOREIGN KEY (cliente_id)  REFERENCES clientes(id),
    CONSTRAINT fk_reservas_vehiculo FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id),
    CONSTRAINT fk_reservas_mecanico FOREIGN KEY (mecanico_id) REFERENCES mecanicos(id) ON DELETE SET NULL,
    CONSTRAINT fk_reservas_puesto   FOREIGN KEY (puesto_id)   REFERENCES puestos(id)   ON DELETE SET NULL,
    CONSTRAINT chk_reserva_fechas CHECK (fecha_fin > fecha_inicio),
    INDEX idx_reservas_fecha (fecha_inicio, fecha_fin),
    INDEX idx_reservas_estado (estado),
    INDEX idx_reservas_mecanico_fecha (mecanico_id, fecha_inicio),
    INDEX idx_reservas_puesto_fecha (puesto_id, fecha_inicio)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Servicios incluidos en cada reserva (N:M)
-- ---------------------------------------------------------------------
CREATE TABLE reserva_servicios (
    reserva_id      INT UNSIGNED NOT NULL,
    servicio_id     INT UNSIGNED NOT NULL,
    cantidad        SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    precio_unitario DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (reserva_id, servicio_id),
    CONSTRAINT fk_rs_reserva  FOREIGN KEY (reserva_id)  REFERENCES reservas(id)  ON DELETE CASCADE,
    CONSTRAINT fk_rs_servicio FOREIGN KEY (servicio_id) REFERENCES servicios(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Historial de cambios de estado de las reservas
-- ---------------------------------------------------------------------
CREATE TABLE reserva_historial (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    reserva_id      INT UNSIGNED NOT NULL,
    estado_anterior VARCHAR(20) NULL,
    estado_nuevo    VARCHAR(20) NOT NULL,
    usuario_id      INT UNSIGNED NULL,
    comentario      VARCHAR(255) NULL,
    fecha           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_rh_reserva FOREIGN KEY (reserva_id) REFERENCES reservas(id) ON DELETE CASCADE,
    CONSTRAINT fk_rh_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Vista: agenda de reservas activas
-- ---------------------------------------------------------------------
CREATE VIEW v_agenda AS
SELECT r.id,
       r.codigo,
       r.fecha_inicio,
       r.fecha_fin,
       r.estado,
       CONCAT(c.nombre, ' ', c.apellidos) AS cliente,
       c.telefono,
       v.matricula,
       CONCAT(v.marca, ' ', v.modelo)     AS vehiculo,
       CONCAT(m.nombre, ' ', m.apellidos) AS mecanico,
       p.nombre                           AS puesto
FROM reservas r
JOIN clientes  c ON c.id = r.cliente_id
JOIN vehiculos v ON v.id = r.vehiculo_id
LEFT JOIN mecanicos m ON m.id = r.mecanico_id
LEFT JOIN puestos   p ON p.id = r.puesto_id
WHERE r.estado NOT IN ('CANCELADA','NO_PRESENTADO');

-- =====================================================================
--  DATOS DE PRUEBA
-- =====================================================================
INSERT INTO usuarios (email, password_hash, rol) VALUES
 ('admin@taller.local',     '$2y$10$CAMBIAR_HASH', 'ADMIN'),
 ('recepcion@taller.local', '$2y$10$CAMBIAR_HASH', 'RECEPCION'),
 ('juan@taller.local',      '$2y$10$CAMBIAR_HASH', 'MECANICO'),
 ('ana@taller.local',       '$2y$10$CAMBIAR_HASH', 'MECANICO');

INSERT INTO mecanicos (usuario_id, nombre, apellidos, especialidad, telefono) VALUES
 (3, 'Juan', 'García López',   'Mecánica general', '600111222'),
 (4, 'Ana',  'Martín Ruiz',    'Electricidad y diagnosis', '600333444');

INSERT INTO puestos (nombre, descripcion) VALUES
 ('Elevador 1', 'Elevador de dos columnas'),
 ('Elevador 2', 'Elevador de tijera'),
 ('Box diagnosis', 'Zona de diagnosis electrónica');

INSERT INTO servicios (nombre, descripcion, duracion_minutos, precio_base) VALUES
 ('Cambio de aceite y filtro', 'Aceite de motor + filtro de aceite', 45, 69.90),
 ('Revisión pre-ITV',          'Comprobación general antes de ITV', 60, 39.90),
 ('Cambio de pastillas de freno', 'Eje delantero o trasero', 90, 95.00),
 ('Diagnosis electrónica',     'Lectura y borrado de errores',       30, 35.00),
 ('Cambio de neumáticos',      'Montaje y equilibrado (4 ruedas)',   60, 40.00),
 ('Carga de aire acondicionado','Revisión y recarga de gas',         45, 59.00);

INSERT INTO horarios_taller (dia_semana, hora_apertura, hora_cierre) VALUES
 (1, '08:00', '14:00'), (1, '15:30', '19:00'),
 (2, '08:00', '14:00'), (2, '15:30', '19:00'),
 (3, '08:00', '14:00'), (3, '15:30', '19:00'),
 (4, '08:00', '14:00'), (4, '15:30', '19:00'),
 (5, '08:00', '14:00'), (5, '15:30', '19:00'),
 (6, '09:00', '13:00');

INSERT INTO dias_cierre (fecha, motivo) VALUES
 ('2026-12-08', 'Inmaculada Concepción'),
 ('2026-12-25', 'Navidad'),
 ('2027-01-01', 'Año Nuevo');

INSERT INTO clientes (nombre, apellidos, dni_nif, telefono, email) VALUES
 ('Laura',  'Sánchez Gómez',  '12345678Z', '611000111', 'laura@example.com'),
 ('Carlos', 'Fernández Díaz', '87654321X', '622000222', 'carlos@example.com');

INSERT INTO vehiculos (cliente_id, matricula, marca, modelo, anio, combustible, kilometraje) VALUES
 (1, '1234ABC', 'Seat',   'León',   2018, 'DIESEL',   98000),
 (2, '5678DEF', 'Toyota', 'Corolla', 2021, 'HIBRIDO', 42000);

INSERT INTO reservas (codigo, cliente_id, vehiculo_id, mecanico_id, puesto_id,
                      fecha_inicio, fecha_fin, estado, canal, importe_estimado) VALUES
 ('RT-2026-0001', 1, 1, 1, 1, '2026-12-01 09:00', '2026-12-01 10:30', 'CONFIRMADA', 'WEB',      164.90),
 ('RT-2026-0002', 2, 2, 2, 3, '2026-12-01 10:00', '2026-12-01 10:30', 'PENDIENTE',  'TELEFONO',  35.00);

INSERT INTO reserva_servicios (reserva_id, servicio_id, cantidad, precio_unitario) VALUES
 (1, 1, 1, 69.90),
 (1, 3, 1, 95.00),
 (2, 4, 1, 35.00);

INSERT INTO reserva_historial (reserva_id, estado_anterior, estado_nuevo, usuario_id, comentario) VALUES
 (1, NULL, 'PENDIENTE', 2, 'Reserva creada'),
 (1, 'PENDIENTE', 'CONFIRMADA', 2, 'Confirmada por teléfono'),
 (2, NULL, 'PENDIENTE', 2, 'Reserva creada');
