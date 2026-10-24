CREATE ROLE soporte NOLOGIN;

CREATE VIEW v_clientes_soporte AS 
SELECT
    id,
    nombre,
    CONCAT(LEFT(correo, 2), '*****', SUBSTRING(correo FROM POSITION('@' IN correo))) AS correo,
    CONCAT('******', RIGHT(telefono, 4)) AS telefono,
    CONCAT('*********', RIGHT(rfc, 4)) AS rfc
FROM clientes;

GRANT USAGE ON SCHEMA public TO soporte;
GRANT SELECT ON v_clientes_soporte TO soporte;
REVOKE ALL ON clientes FROM soporte;

SET ROLE soporte;
SELECT * FROM v_clientes_soporte;

SELECT * FROM clientes;

RESET ROLE;