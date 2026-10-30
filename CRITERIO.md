# Criterio

## 1. ADR-001: ¿dónde viven los pipelines y con qué herramienta?

**Contexto.** Una célula de 6 personas atiende a equipos de Go, Python y React que quieren
desplegar solos. Hoy hay un servicio; pronto habrá muchos repositorios.

**Decisión.** Una **plantilla central que cada repo usa**. DevOps mantiene workflows
reutilizables y versionados (por ejemplo `uses: ministerio/pipelines/.github/workflows/python.yml@v1`)
y cada equipo tiene un `deploy.yml` de pocas líneas que los llama. DevOps decide *cómo* se
construye y se despliega de forma segura; el equipo decide *cuándo* y *qué* despliega.
Herramienta: **GitHub Actions**, entrando a GCP con Workload Identity Federation.

**Lo que descarté.**
- *Un pipeline distinto en cada repo:* cada equipo reinventa la seguridad y un arreglo no
  llega a los demás.
- *Un solo pipeline central que despliega todo:* se vuelve cuello de botella y los equipos
  vuelven a depender de DevOps.
- *Cloud Build:* se integra muy bien con GCP, pero el código, los PR y los checks ya están en
  GitHub. Tener los dos duplica dónde buscar logs y permisos, y para este flujo Actions alcanza.

**Lo revisaría si** algún build tiene que correr dentro de la red privada, si hay requisitos
de dónde corren los runners, o si los minutos de Actions empiezan a costar más que Cloud Build.

## 2. Cinco automatizaciones para el primer trimestre

Las ordené por **cuánto riesgo y trabajo repetido quitan, dividido entre lo que cuestan**, y
puse primero lo que deja a los equipos avanzar sin pasar por la célula.

1. **Plantilla de pipeline** para Python, Go y React (pruebas, imagen versionada, escaneo y
   deploy). Es lo que piden los equipos y lo que más tickets elimina.
2. **Alta de servicio en autoservicio:** un módulo de Terraform donde el equipo pone nombre y
   dueño, y obtiene repo de imágenes, cuenta de servicio, secreto y Cloud Run con permisos
   mínimos.
3. **`terraform plan` en cada PR y detección de drift diaria:** nadie aplica a ciegas y un
   cambio hecho a mano en la consola aparece al día siguiente.
4. **Seguridad dentro de la plantilla:** secretos, vulnerabilidades y firma de imágenes (Binary
   Authorization) para los programas críticos. Cuesta poco cuando ya existe la plantilla.
5. **Observabilidad desde el día uno:** cada servicio nace con dashboard, uptime check,
   alertas de errores y latencia, y presupuesto por equipo.

## 3. ¿Cómo aseguro que al menos la mitad del tiempo sea ingeniería?

- **Medirlo.** Cada ticket se marca como *ingeniería* (automatizar, plataforma, deuda) u
  *operación* (pedidos, incidentes, accesos manuales). Sin medirlo, es una opinión.
- **Un límite claro.** Si la operación pasa del 50 % dos semanas seguidas, la semana siguiente
  se dedica a automatizar la causa más grande.
- **Guardia rotativa.** Una o dos personas por semana atienden la operación; el resto queda
  protegido para proyectos.
- **Regla de tres.** Un pedido que llega tres veces se convierte en automatización o en
  autoservicio con documentación.
- **Revisión semanal de 30 minutos:** porcentaje de ingeniería contra operación; los 3 pedidos
  manuales más comunes; incidentes y sus acciones pendientes; métricas DORA (frecuencia de
  despliegue, tiempo de entrega, tasa de fallos y tiempo de recuperación); y gasto contra
  presupuesto.
