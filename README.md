# PNKSecurity

## CI3064 — Desarrollo Seguro

PNKSecurity es una aplicación web utilizada como **caso de estudio práctico** en la asignatura **Desarrollo Seguro (CI3064)**.

Durante la Unidad 1, el sistema fue analizado desde una perspectiva DevSecOps, identificando posibles riesgos, vulnerabilidades y oportunidades de mejora.

En la **Unidad 2 — Desarrollo y Pruebas de Software Seguro**, los equipos trabajarán directamente con el código fuente de la aplicación.

---

## Objetivo del trabajo

El propósito de esta etapa es analizar una aplicación existente y aplicar progresivamente principios y buenas prácticas de desarrollo seguro.

A partir de este repositorio, cada equipo deberá comprender el funcionamiento del sistema, preparar un ambiente de ejecución controlado y posteriormente implementar y verificar mejoras de seguridad.

Durante la unidad se abordarán temas relacionados con:

* ética y conciencia de seguridad;
* ciclo de vida de desarrollo seguro;
* ISO/IEC 27034;
* validación de entradas;
* protección de datos sensibles;
* gestión de sesiones y cookies;
* amenazas y vulnerabilidades.

---

## Estado del repositorio

El repositorio contiene el código fuente base de PNKSecurity.

El ambiente de ejecución **no se entrega completamente configurado**.

Como parte del trabajo de la unidad, cada equipo deberá investigar y determinar los requerimientos necesarios para ejecutar correctamente la aplicación en un ambiente local controlado.

Esto puede implicar analizar aspectos relacionados con:

* tecnologías utilizadas;
* dependencias;
* servicios requeridos;
* base de datos;
* contenedores;
* configuración del ambiente;
* variables de entorno.

La solución adoptada deberá ser comprendida y documentada por el equipo.

---

## Forma de trabajo

Antes de realizar modificaciones importantes al código, el equipo deberá comprender el funcionamiento general de la aplicación y establecer una línea base de su estado inicial.

Durante la unidad se trabajará siguiendo el principio:

**Analizar → identificar el problema → proponer una mejora → implementar → probar → documentar evidencia.**

Las modificaciones realizadas deberán quedar registradas en el repositorio y permitir comprender la evolución del proyecto.

---

## Seguridad del repositorio

El repositorio utilizado durante el curso no debe contener información sensible.

No deben incorporarse:

* contraseñas reales;
* credenciales institucionales;
* tokens;
* claves API;
* datos personales reales;
* secretos utilizados por servicios externos.

Los equipos deberán aplicar buenas prácticas para administrar la configuración y los secretos necesarios para ejecutar el proyecto.

---

## Uso de Inteligencia Artificial

Durante el desarrollo del proyecto se permite utilizar herramientas de Inteligencia Artificial como apoyo para:

* investigar tecnologías;
* comprender código;
* interpretar errores;
* comparar alternativas;
* proponer soluciones;
* revisar documentación.

El uso de IA no reemplaza la comprensión del equipo.

Cada estudiante debe ser capaz de **explicar, justificar y demostrar técnicamente las decisiones implementadas en el proyecto**.

---

## Importante

PNKSecurity es un entorno académico utilizado exclusivamente para actividades autorizadas dentro de la asignatura.

Las pruebas de seguridad deberán realizarse únicamente sobre los ambientes indicados por el docente y respetando las condiciones establecidas durante el curso.

---

## CI3064 — Desarrollo Seguro

**Caso de estudio: PNKSecurity**

> La meta no es solamente hacer que el software funcione, sino comprender cómo desarrollarlo, probarlo y mejorarlo de forma segura.

---

## Ejecución local (entorno del equipo, Unidad 2)

Requisitos: Docker y Docker Compose. No hace falta instalar PHP ni MySQL en la máquina.

```bash
cp .env.example .env        # y reemplazar las claves de ejemplo
docker compose up -d --build
```

| Servicio | URL | Nota |
| --- | --- | --- |
| Aplicación | http://127.0.0.1:8080/?id=1 | PHP 8.3 + Apache (`Dockerfile`) |
| Base de datos | `db:3306` (solo red interna) | MySQL 8.0; importa `Script_BD/pnk_security.sql` al primer arranque |
| phpMyAdmin | http://127.0.0.1:8081 | Solo local; pide usuario y clave (los de `.env`) |

La aplicación lee la conexión a la base desde las variables `DB_HOST`, `DB_NAME`, `DB_USER` y
`DB_PASSWORD` que define `compose.yaml` a partir de `.env`. Para reiniciar la base desde cero:
`docker compose down -v`.

## Evidencias de la Sumativa 2

Las evidencias E-01 a E-25 del informe (capturas, salidas de terminal, trazabilidad Git) y los
scripts que las generan están en [`evidencias/`](evidencias/README.md).
