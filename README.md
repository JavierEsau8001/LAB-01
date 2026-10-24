# LAB-01# Informe Técnico: Laboratorio 01 - Protección y Privacidad de Datos

**Materia:** Gestión de Seguridad y Desempeño de Bases de Datos  
**Unidad:** II - Seguridad, privacidad y control de acceso  
**Tema:** 2.3 Datos sensibles, privacidad y protección de la información  
**Motor SGBD:** PostgreSQL 16  
**Organización Evaluada:** Comercializadora Norte S.A. de C.V.  

---

## 1. Clasificación de Datos

### 1.1 Matriz de Clasificación
A continuación se presenta la categorización de los atributos que componen la entidad `clientes`, determinando su nivel de criticidad e impacto:

| Campo | ¿Identifica directamente? | ¿Puede contribuir a identificar? | ¿Requiere protección? | Justificación Técnica |
| :--- | :---: | :---: | :---: | :--- |
| `id` | No | Sí | Sí | Identificador primario relacional. Por sí mismo es opaco, pero permite indexar transacciones e historiales. |
| `nombre` | **Sí** | Sí | **Sí** | Identificador directo inequívoco del titular del dato personal. |
| `correo` | **Sí** | Sí | **Sí** | Identificador directo y canal de contacto unívoco; usualmente empleado como credencial de acceso. |
| `telefono` | **Sí** | Sí | **Sí** | Identificador directo de contacto y localización personal. |
| `rfc` | **Sí** | Sí | **Sí** | Clave unívoca gubernamental vinculada al historial fiscal y legal del titular. |
| `edad` | No | **Sí** | Sí | Cuasi-identificador demográfico. Reduce el universo de búsqueda. |
| `ciudad` | No | **Sí** | Sí | Cuasi-identificador de ubicación geográfica media. |
| `codigo_postal` | No | **Sí** | Sí | Cuasi-identificador de alta precisión territorial (micro-localización). |
| `fecha_alta` | No | **Sí** | Opcional / Sí | Metadato operativo que en universos acotados permite delimitar altas específicas. |

### 1.2 Análisis de Identificadores y Cuasi-identificadores
* **Identificadores directos:** `nombre`, `correo`, `telefono`, `rfc`. Revelan la identidad de la persona sin requerir información complementaria.
* **Cuasi-identificadores:** `edad`, `ciudad`, `codigo_postal`, `fecha_alta`. No identifican por sí solos, pero reducen drásticamente la entropía de anonimato.
* **Combinación de riesgo de reidentificación:** La combinación simultánea de `(edad + ciudad + codigo_postal)` permite aislar a individuos particulares al ser cruzada con fuentes de datos abiertas (directorios públicos, padrones, redes sociales), posibilitando un ataque de enlace (*linkage attack*).
* **Perspectiva Jurídica vs. Técnica:** No todos los datos que requieren protección técnica son catalogados formalmente como "datos personales sensibles" bajo los marcos legales (como origen étnico, biométricos o estados de salud). No obstante, al constituir información personal privada identificable, la organización tiene la obligación de salvaguardarla bajo el principio de minimización y seguridad de la información.

---

## 2. Enmascaramiento (Masking)

* **¿Qué información se ocultó?:** Se enmascararon parcialmente las cadenas de `correo` (dejando solo los 2 primeros caracteres y el dominio), `telefono` (ocultando los primeros 6 dígitos y dejando legibles los últimos 4) y `rfc` (ocultando los primeros 9 caracteres y preservando únicamente la homoclave).
* **¿Para quién?:** Para el rol de base de datos `soporte`.
* **¿Por qué?:** El personal de soporte al cliente requiere confirmar que está interactuando con el titular legítimo (mediante validaciones de terminación telefónica o iniciales de correo), pero no precisa disponer del dato en texto plano para cumplir su función operativa.
* **¿Qué mecanismo se utilizó?:** Se construyó una vista SQL (`v_clientes_soporte`) que aplica transformaciones dinámicas de presentación mediante funciones de cadena (`CONCAT`, `LEFT`, `RIGHT`, `SUBSTRING`, `POSITION`).
* **Control de acceso asociado:** Se otorgó `USAGE` en el esquema `public` y `SELECT` exclusivamente sobre la vista `v_clientes_soporte`, revocando todo permiso directo sobre la tabla física base (`REVOKE ALL ON clientes FROM soporte;`). De esta forma, si el usuario ejecuta un `SELECT * FROM clientes`, el motor PostgreSQL aborta la petición por violación de privilegios.

---

## 3. Seudonimización (Pseudonymization)

* **Generación de identificadores sustitutos (Tokens):** Se utilizó la función criptográfica `gen_random_uuid()` provista por la extensión `pgcrypto` para asignar a cada registro un token UUID versión 4 irreversible y no correlativo con la clave primaria secuencial.
* **Ubicación del mapa de correspondencia:** Se diseñó el esquema dedicado `pii`, alojando en su interior la tabla `pii.mapa_cliente (token UUID, cliente_id BIGINT)`.
* **Acceso y custodia:** El acceso a este mapa debe estar estrictamente limitado al administrador de base de datos (DBA) o a procesos de sincronización internos de backend altamente restringidos. El rol `analista` tiene denegado el acceso tanto al esquema `pii` como a la tabla `clientes`.
* **Separación de funciones (*Separation of Duties*):** La seudonimización pierde su eficacia si quien analiza los datos dispone de la llave para des-anonimizarlos. Al conceder al rol `analista` acceso únicamente a la tabla `analitica.clientes` (que aloja atributos demográficos ligados al `cliente_token`), el equipo de analítica puede modelar tendencias y patrones estadísticos sin capacidad de ligar las observaciones con identidades civiles.

---

## 4. Anonimización (Anonymization)

* **Identificadores eliminados:** Se suprimieron en su totalidad `nombre`, `correo`, `telefono` y `rfc`.
* **Atributos generalizados:** 
  * La variable continua `edad` se agrupó en rangos categóricos (`18-30`, `31-45`, `46+`).
  * La precisión espacial del `codigo_postal` se redujo tomando únicamente los primeros dos dígitos (`LEFT(codigo_postal, 2)`), transformando la ubicación de manzana/colonia a zona macro-regional.
* **Supresión de grupos pequeños ($k$-anonymity didáctico):** Se implementó la cláusula `HAVING COUNT(*) >= 5` para condicionar la visualización a grupos con al menos 5 elementos. En muestras reducidas donde una combinación arroja valores menores al umbral, el registro es omitido para evitar que combinaciones infrecuentes de atributos singularicen a un usuario.
* **Riesgo residual de reidentificación:** A pesar de la agregación, un umbral arbitrario no garantiza anonimato absoluto. Si un grupo cumple $k \ge 5$ pero todos los individuos del grupo comparten una misma condición homogénea (falta de diversidad), un observador podría deducir dicha condición sin necesidad de aislar un único registro (*homogeneity attack*).

---

## 5. Retención de Datos

* **Criterio establecido:** Se definió una ventana temporal de retención máxima de **5 años** para cuentas o historiales pasivos a partir de `fecha_alta`:
  ```sql
  SELECT * FROM clientes WHERE fecha_alta < CURRENT_DATE - INTERVAL '5 years';
  ```
* **Información a conservar vs. eliminar:** Se debe conservar únicamente información ligada a obligaciones fiscales o de auditoría mercantil durante los plazos legalmente estipulados. La información transaccional obsoleta, historiales de navegación o perfiles sin actividad deben ser depurados.
* **Controles y gobernanza de purga:**
  1. No realizar ejecuciones directas de `DELETE` en producción sin visto bueno del Oficial de Protección de Datos (DPO) y el área jurídica.
  2. Implementar mecanismos de respaldo lógico (*pg_dump*) cifrado en almacenamiento frío previo a la eliminación.
  3. Aplicar estrategias de eliminación lógica (*soft delete*, por ejemplo actualizando una bandera `activo = FALSE`) durante un período de cuarentena de 30 días antes de la purga física definitiva mediante tareas por lotes programadas.

---

## 6. Conclusiones por Escenario de Uso

1. **Área de Soporte:**  
   *Técnica óptima:* **Enmascaramiento dinámico mediante vistas**. Permite a los agentes validar datos operativos en tiempo de atención telefónica o chat sin exponer los datos crudos en texto plano.
2. **Área de Analítica:**  
   *Técnica óptima:* **Seudonimización con separación de esquemas (RBAC)**. Preserva la granularidad fila por fila para correlacionar eventos a lo largo del tiempo sin requerir identificadores directos, resguardando la tabla puente fuera del alcance del analista.
3. **Publicación Externa o Información para Dirección:**  
   *Técnica óptima:* **Anonimización por agregación y generalización**. Presenta indicadores consolidados (conteos, frecuencias, promedios) con supresión de subconjuntos pequeños, eliminando la exposición de cualquier registro individual.
4. **Indispensabilidad del Control de Acceso:**  
   Ninguna de las técnicas anteriores es autosuficiente sin una capa estricta de control de acceso (roles, esquemas, `GRANT`/`REVOKE`). El enmascaramiento o la seudonimización son inútiles si la cuenta de servicio o el usuario conserva privilegios directos de lectura sobre las tablas maestras.

---

## 7. Preguntas de Reflexión

### 1. ¿Cuál es la diferencia entre enmascaramiento y seudonimización?
El **enmascaramiento** altera únicamente la presentación visual del dato (ocultando caracteres mediante asteriscos o patrones) sin modificar el dato subyacente almacenado. La **seudonimización** sustituye activamente un identificador directo por un valor artificial o token, desacoplando la identidad de forma persistente y delegando la asociación a una tabla de correspondencia protegida.

### 2. ¿Por qué la seudonimización no significa anonimización?
Porque la seudonimización es intrínsecamente **reversible**: existe un mecanismo (la tabla de correspondencia o una función con clave) que permite ligar de nuevo el token con el titular legítimo. En contraste, la anonimización persigue un estado irreversible donde la reidentificación razonable resulta técnicamente inviable.

### 3. ¿Por qué eliminar nombre y RFC no garantiza que un conjunto de datos sea anónimo?
Porque los atributos residuales (edad, lugar de residencia, género, código postal) continúan actuando como cuasi-identificadores. Al cruzarse con bases de datos públicas, la combinación específica de variables demográficas puede singularizar a una sola persona dentro de la muestra.

### 4. ¿Qué función tienen los cuasi-identificadores?
Actúan como atributos de enlace. Aunque tomados de forma individual no distinguen a un sujeto, la conjunción de múltiples cuasi-identificadores reduce drásticamente el espacio de búsqueda hasta volver al individuo identificable.

### 5. ¿Por qué es importante separar el mapa de seudonimización?
Si el mapa de correspondencia reside en el mismo espacio o bajo los mismos privilegios que los datos seudonimizados, cualquier usuario con permisos de lectura puede reconstruir las identidades mediante un simple `JOIN`, anulando la efectividad del control.

### 6. ¿Qué principio de seguridad se aplica al impedir que el analista acceda al mapa?
El principio de **Mínimo Privilegio (*Least Privilege*)** y el principio de **Separación de Funciones (*Separation of Duties*)**. El analista únicamente recibe los permisos requeridos para generar inteligencia de negocio, bloqueando el acceso a llaves criptográficas o tablas puente.

### 7. ¿Por qué una vista puede ser preferible a entregar acceso directo a la tabla?
Porque la vista actúa como una barrera de abstracción y filtrado en la capa de base de datos. Permite aplicar enmascaramiento, proyecciones de columnas seguras y restricciones de filas de forma transparente, sin duplicar datos ni confiar en que la aplicación cliente filtre la información sensible.

### 8. ¿Qué diferencia existe entre proteger un dato para visualización y protegerlo contra acceso no autorizado?
Protegerlo para visualización (como enmascarar en una interfaz) solo previene la observación incidental en pantalla; si el usuario tiene privilegios en la base de datos, puede saltarse la interfaz y leer los datos en texto claro. Protegerlo contra acceso no autorizado implica barreras a nivel de motor de base de datos (roles, permisos de objeto, cifrado), garantizando que nadie sin autorización explícita pueda acceder al valor real.

### 9. ¿Por qué la retención forma parte de la protección de datos?
Porque responde al principio de **Minimización de Datos**. La información que ya no es necesaria para la finalidad con la que fue recabada deja de tener justificación operativa, y mantenerla solo incrementa el riesgo y el pasivo legal ante una eventual fuga.

### 10. ¿Qué riesgo existe si una organización conserva información indefinidamente?
Se incrementa exponencialmente la superficie de ataque y el impacto potencial de un incidente de seguridad (filtraciones, multas regulatorias por incumplimiento normativo de protección de datos personales y costos innecesarios de almacenamiento y mantenimiento).
