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
