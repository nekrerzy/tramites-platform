# Criterio técnico

> Borrador: reescribir con tus palabras. Es un punto de partida generado con IA; la versión
> final debe reflejar tu propio juicio y experiencia.

## 1. ADR-001: dónde viven los pipelines y con qué herramienta

**Contexto.** Una célula de 6 personas da servicio a equipos Go, Python y React que quieren
desplegar sin pedirle nada a DevOps. Hoy hay un servicio; mañana habrá varios repos.

**Decisión.** *Pipelines centralizados como plantilla, ejecutados en cada repo*: los equipos
llaman workflows reutilizables versionados (`uses: ministerio/pipelines/.github/workflows/python.yml@v1`)
desde un `deploy.yml` corto en su repo. DevOps es dueño de la plantilla (build, firma,
deploy, seguridad); el equipo es dueño de cuándo y qué despliega. Herramienta: **GitHub
Actions**, autenticado a GCP con Workload Identity Federation.

**Descartado.**
- *Un pipeline completo y distinto por repo*: cada equipo reinventa seguridad y firma; los
  arreglos no se propagan; deriva entre repos.
- *Un pipeline único central que despliega todo*: cuello de botella y punto único de falla;
  los equipos vuelven a depender de DevOps para cada cambio.
- *Cloud Build*: integra nativo con GCP (sin WIF, pools privados en VPC), pero el código, los
  PR, los checks obligatorios y la experiencia del desarrollador ya están en GitHub; sumar
  Cloud Build duplica dónde mirar logs y permisos. Para lo que hace este pipeline, Actions
  alcanza y es gratis en repos públicos.

**Revisar cuando** haya builds que deban correr dentro de la red privada (acceso a recursos
sin IP pública), requisitos de residencia/soberanía de datos de los runners, o el costo de
minutos de Actions supere al de Cloud Build. También si se adopta Cloud Deploy para
promociones entre ambientes.

## 2. Las 5 automatizaciones del primer trimestre

Criterio de orden: **(riesgo que elimina × frecuencia) / esfuerzo**, y primero lo que
desbloquea a los equipos sin pasar por la célula.

1. **Plantilla de pipeline reutilizable** (build, pruebas, firma, deploy por digest) para
   Python, Go y React. Es el pedido explícito de los equipos y lo que más tickets elimina.
2. **Alta de servicio self-service**: un módulo de Terraform (`service = { name, team }`) que
   crea repo de AR, cuenta de servicio, secreto y servicio Cloud Run con mínimo privilegio.
3. **Plan de Terraform en cada PR + drift diario** con issue automático: nadie aplica a ciegas
   y los cambios en consola se ven al día siguiente.
4. **Seguridad en el pipeline**: escaneo de secretos y de vulnerabilidades, Binary
   Authorization obligatoria. Barato una vez que existe la plantilla (1).
5. **Observabilidad por defecto**: dashboard, uptime check y alertas de error/latencia (SLO)
   creados con cada servicio, más presupuestos por equipo.

## 3. Al menos 50 % del tiempo en ingeniería

- **Medirlo**: etiquetar cada ticket como *ingeniería* (automatización, plataforma, deuda) u
  *operación* (pedidos, incidentes, accesos manuales). Sin medición es una opinión.
- **Límite explícito**: si la operación pasa del 50 % dos semanas seguidas, la siguiente
  semana se prioriza automatizar la causa principal de esa operación.
- **Rotación de guardia**: una o dos personas absorben la operación cada semana; el resto
  queda protegido para proyectos.
- **Todo pedido repetido tres veces se convierte en automatización o en self-service** con
  documentación.
- **Revisión semanal (30 min)**: % ingeniería vs operación; top 3 tipos de pedido manual;
  incidentes y acciones pendientes; frecuencia de despliegue, lead time, tasa de fallo y MTTR
  (DORA); issues de drift abiertos; gasto vs presupuesto.
