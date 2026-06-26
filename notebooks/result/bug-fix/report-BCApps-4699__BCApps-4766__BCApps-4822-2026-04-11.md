# Análisis de resultados: BCApps-4699, BCApps-4766 y BCApps-4822

Fecha: 2026-04-11

## Alcance

Este informe resume 15 ejecuciones por instancia (3 setups × 5 runs):

- `claude-opus-4-5`
- `copilot-opus-4-5`
- `copilot-opus-4-6`

Fuentes usadas:

- `/home/runner/work/BC-Bench/BC-Bench/notebooks/result/bug-fix/*/*.jsonl`
- `/home/runner/work/BC-Bench/BC-Bench/dataset/bcbench.jsonl`

## Resumen ejecutivo

Hay dos comportamientos claramente distintos:

1. **`BCApps-4699` y `BCApps-4822` son bugs solucionables con bastante frecuencia**. Ambos superan el 70% de resolución agregada.
2. **`BCApps-4766` es el caso realmente problemático**. Ningún setup lo resuelve, aunque todos construyen correctamente, así que el fallo es semántico y no de compilación.

La consecuencia práctica es importante: **mirar solo el build rate aquí lleva a conclusiones erróneas**.

## Resultados agregados por instancia

| Instancia | Proyecto | Qué corrige el patch esperado | Resolución | Build | Lectura rápida |
| --- | --- | --- | ---: | ---: | --- |
| `microsoft__BCApps-4699` | Shopify | Conversión FCY→LCY al crear items desde Shopify | 12/15 (80.0%) | 12/15 (80.0%) | Caso bastante abordable |
| `microsoft__BCApps-4766` | Subscription Billing | Desconectar la Subscription Line al vaciar `No.` en contratos customer/vendor | 0/15 (0.0%) | 15/15 (100.0%) | Caso difícil y semántico |
| `microsoft__BCApps-4822` | Shopify | Propagar `Sell-to` y `Bill-to` al crear Company Location | 11/15 (73.3%) | 15/15 (100.0%) | Caso medio, normalmente resoluble |

## Detalle por instancia

### BCApps-4699

**Bug esperado:** al crear un item desde Shopify, `Unit Cost` y `Unit Price` deben convertirse de la moneda de la tienda a LCY.

**Resultados por setup:**

| Setup | Resolución |
| --- | ---: |
| `claude-opus-4-5` | 4/5 |
| `copilot-opus-4-5` | 3/5 |
| `copilot-opus-4-6` | 5/5 |

**Qué se observa:**

- Es un bug bastante localizado: una vez se identifica la necesidad de usar la tasa de cambio, la solución es directa.
- El único patrón de fallo etiquetado aparece en `copilot-opus-4-5`: **`Missing Using`** en 2 de 5 ejecuciones.
- `copilot-opus-4-6` mejora claramente y alcanza **5/5**, lo que sugiere una mejor ejecución de fixes con dependencias adicionales.

**Conclusión:** es un buen ejemplo de tarea que discrimina entre agentes que “ven” la intención del cambio y agentes que además cierran bien los detalles de integración.

### BCApps-4766

**Bug esperado:** al limpiar el campo `No.` en líneas de contrato de cliente y proveedor, la `Subscription Line` asociada debe quedar desconectada.

**Resultados por setup:**

| Setup | Resolución |
| --- | ---: |
| `claude-opus-4-5` | 0/5 |
| `copilot-opus-4-5` | 0/5 |
| `copilot-opus-4-6` | 0/5 |

**Qué se observa:**

- **Todos los runs compilan**, pero **ninguno resuelve el bug**.
- En `copilot-opus-4-5` los 5 fallos quedaron revisados como **`Wrong Solution`**.
- En los otros setups no hay etiqueta de revisión fina, pero el patrón agregado es el mismo: cambio insuficiente aunque el código siga construyendo.
- El patch esperado no es solo “permitir `No.` vacío”; también exige **desconectar el vínculo contractual** y hacerlo de forma simétrica en customer y vendor.

**Conclusión:** este caso mide razonamiento sobre invariantes de negocio y efectos laterales, no solo edición sintáctica. También deja claro que **build = éxito** es una métrica engañosa para bugs de dominio.

### BCApps-4822

**Bug esperado:** al crear una company location desde un customer, deben persistirse correctamente `Sell-to Customer No.` y `Bill-to Customer No.`.

**Resultados por setup:**

| Setup | Resolución |
| --- | ---: |
| `claude-opus-4-5` | 3/5 |
| `copilot-opus-4-5` | 4/5 |
| `copilot-opus-4-6` | 4/5 |

**Qué se observa:**

- El caso es más difícil que 4699, pero sigue siendo resoluble con frecuencia alta.
- Todos los runs construyen, y solo 1 fallo revisado aparece como **`Wrong Solution`**.
- El fix correcto requiere pasar de un identificador (`CustomerId`) al registro `Customer` completo para rellenar más campos; es decir, hay que detectar que el dato “ya existe” pero no se está propagando.

**Conclusión:** es un bug de propagación de datos relativamente asequible para los agentes actuales, aunque todavía hay runs que implementan una solución parcial.

## Conclusiones principales

1. **Los tres issues no tienen la misma dificultad.**
   `BCApps-4699` y `BCApps-4822` parecen tareas razonablemente maduras para evaluación de agentes. `BCApps-4766`, en cambio, es un caso duro de lógica de negocio.

2. **`BCApps-4766` es el hallazgo más relevante del lote.**
   Si el objetivo es diferenciar agentes por comprensión semántica, este issue aporta mucha señal porque todos compilan y todos fallan en el comportamiento esperado.

3. **`copilot-opus-4-6` mejora de forma clara en `BCApps-4699`, pero no rompe el techo en `BCApps-4766`.**
   Hay progreso en fixes localizados, pero no en invariantes de dominio con efectos laterales.

4. **El build rate no basta para interpretar estos resultados.**
   En `BCApps-4766` el build rate es 100% y la resolución 0%. Si se reporta solo compilación, se sobreestima mucho la capacidad real del agente.

5. **La muestra es útil, pero pequeña.**
   Son 5 runs por setup, así que las diferencias entre 3/5, 4/5 y 5/5 deben leerse como tendencia, no como verdad definitiva.

## Recomendación práctica

Si hay que extraer una conclusión operativa de estos tres casos:

- usaría **`BCApps-4699` y `BCApps-4822`** como ejemplos de bugs productivos para medir capacidad de resolución real;
- usaría **`BCApps-4766`** como caso de control para detectar agentes que compilan pero no respetan la lógica de negocio.
