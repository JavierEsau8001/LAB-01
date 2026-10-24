-- Generalización de edad y región
SELECT 
    CASE 
        WHEN edad BETWEEN 18 AND 30 THEN '18-30'
        WHEN edad BETWEEN 31 AND 45 THEN '31-45'
        ELSE '46+' 
    END AS rango_edad,
    LEFT(codigo_postal, 2) AS region,
    COUNT(*) AS total
FROM clientes 
GROUP BY 1, 2;

-- Supresión de grupos pequeños (k >= 5)
SELECT 
    CASE 
        WHEN edad BETWEEN 18 AND 30 THEN '18-30'
        WHEN edad BETWEEN 31 AND 45 THEN '31-45'
        ELSE '46+' 
    END AS rango_edad,
    LEFT(codigo_postal, 2) AS region,
    COUNT(*) AS total
FROM clientes 
GROUP BY 1, 2 
HAVING COUNT(*) >= 5;

