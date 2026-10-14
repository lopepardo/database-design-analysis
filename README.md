# Bitácora de análisis y diseño de bases de datos

Este repositorio reúne el análisis y el diseño de bases de datos relacionales mediante proyectos prácticos. Cada proyecto documentará el recorrido desde el enunciado del problema hasta un modelo de datos, junto con las decisiones tomadas, las dudas y lo aprendido.

## Proyectos

| Proyecto                      | Carpeta                                                          |
| ----------------------------- | ---------------------------------------------------------------- |
| Reserva de coches             | [car-reservation](car-reservation/README.md)                     |
| Coordinadora nacional de ONGs | [national-ngo-coordination](national-ngo-coordination/README.md) |
| Torneo de ajedrez             | [chess-tournament](chess-tournament/README.md)                   |

## Metodología de trabajo

Cada proyecto sigue este recorrido:

1. **Analizar el enunciado.** Identificar los datos que se necesitan, las reglas de negocio y las ambigüedades que requieren una interpretación.
2. **Identificar entidades y relaciones.** Definir los atributos, los identificadores y las cardinalidades mínimas y máximas de cada relación.
3. **Construir el modelo conceptual.** Representar las entidades, los atributos y las relaciones en notación Chen, incluyendo entidades débiles y subtipos cuando corresponda.
4. **Transformar el modelo al esquema relacional.** Definir las tablas, las claves primarias y foráneas, y las tablas intermedias necesarias para las relaciones N:M.
5. **Implementar el esquema en PostgreSQL.** Crear las tablas y sus restricciones, y añadir vistas, funciones o disparadores cuando sean necesarios para las reglas del proyecto.
6. **Registrar las decisiones y lo aprendido.** Explicar los supuestos adoptados, las dudas y los aprendizajes, distinguiendo las reglas garantizadas por el SQL de las que aún requieren lógica adicional.

## Estructura del repositorio

```text
.
├── README.md
├── car-reservation/
├── national-ngo-coordination/
└── chess-tournament/
```

El `README.md` de la raíz presenta la bitácora y enlaza los proyectos. Las tres carpetas de proyecto comparten esta organización:

| Archivo | Contenido |
| ------- | --------- |
| `README.md` | Enunciado, diseño, decisiones, implementación y aprendizajes del proyecto. |
| `schema.sql` | Implementación del esquema en PostgreSQL. |
| `diagrams/ER-diagram-chen-notation.png` | Imagen del modelo conceptual en notación Chen. |
| `diagrams/ER-diagram.png` | Imagen del modelo lógico relacional. |
| `diagrams/<nombre-del-proyecto>.drawio` | Fuente editable de ambos diagramas; el nombre coincide con la carpeta del proyecto. |

## Referencias

- [Restricciones de PostgreSQL: PK, FK, CHECK y acciones de borrado](https://www.postgresql.org/docs/current/ddl-constraints.html).
- [Columnas de identidad](https://www.postgresql.org/docs/current/ddl-identity-columns.html).
- [Funciones de disparador en PL/pgSQL](https://www.postgresql.org/docs/current/plpgsql-trigger.html).
- [Transacciones](https://www.postgresql.org/docs/current/tutorial-transactions.html).
- [Manual de psql](https://www.postgresql.org/docs/current/app-psql.html).
