-- Script de inicialización de base de datos
-- Crea schemas separados para cada microservicio

-- Crear schemas
CREATE SCHEMA IF NOT EXISTS users_schema;
CREATE SCHEMA IF NOT EXISTS orders_schema;
CREATE SCHEMA IF NOT EXISTS notifications_schema;

-- Asignar permisos
GRANT ALL PRIVILEGES ON SCHEMA users_schema TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA orders_schema TO postgres;
GRANT ALL PRIVILEGES ON SCHEMA notifications_schema TO postgres;

-- Configurar search_path por defecto
ALTER DATABASE microservices_db SET search_path TO users_schema, orders_schema, notifications_schema, public;
