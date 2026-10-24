CREATE SCHEMA pii;
CREATE SCHEMA analitica;

CREATE TABLE pii.mapa_cliente (
    token UUID PRIMARY KEY,
    cliente_id BIGINT UNIQUE REFERENCES public.clientes(id)
);

CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO pii.mapa_cliente (token, cliente_id)
SELECT gen_random_uuid(), id FROM clientes;

CREATE TABLE analitica.clientes AS 
SELECT
    m.token AS cliente_token,
    c.edad,
    c.ciudad,
    c.codigo_postal,
    c.fecha_alta
FROM pii.mapa_cliente m
JOIN clientes c ON c.id = m.cliente_id;

CREATE ROLE analista NOLOGIN;
GRANT USAGE ON SCHEMA analitica TO analista;
GRANT SELECT ON analitica.clientes TO analista;

SET ROLE analista;

-- 1. Permitido (Data Output exitoso):
SELECT * FROM analitica.clientes;

-- 2. Rechazado (Genera error en Messages):
SELECT * FROM pii.mapa_cliente;

-- 3. Rechazado (Genera error en Messages):
SELECT * FROM public.clientes;

-- Restaurar administrador:
RESET ROLE;