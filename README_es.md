# Análisis de confiabilidad de máquinas – Contoso Retail (2007–2009)

Análisis en SQL Server de las fallas de las máquinas de una cadena minorista: **MTBF**, **MTTR** y **disponibilidad** por tipo de máquina, para definir dónde enfocar el mantenimiento.

🇬🇧 [English version](README.md)

**Autor:** Juan · **Herramientas:** SQL Server, SSMS · **Base:** ContosoRetailDW (Microsoft)

---

## Preguntas

1. ¿Cada cuánto falla cada tipo de máquina? → **MTBF** (tiempo medio entre fallas)
2. ¿Cuánto se tarda en repararla? → **MTTR** (tiempo medio de reparación)
3. ¿Qué porcentaje del tiempo estuvo funcionando? → **Disponibilidad**
4. ¿Dónde conviene poner el foco de mantenimiento?

## Datos

| Tabla | Contenido |
|---|---|
| `FactITSLA` | Una fila por falla: máquina, tienda, tipo de falla, inicio, fin y minutos caídos |
| `DimMachine` | Catálogo de máquinas: tipo, fecha de inicio de servicio y fecha de baja |
| `DimOutage` | Catálogo de tipos de falla |

- **4.925 fallas**, del 01/01/2007 al 31/12/2009 (3 años completos).
- **7.816 máquinas** en 9 tipos; **2.553 (33%)** tuvieron al menos una falla.

## Validación de datos

Antes de calcular, se verificó:

- **Unidad de `DownTime`:** la columna no indica su unidad. Se comparó con la diferencia en minutos entre inicio y fin de cada falla: coincide en el 100% de las filas, sin fechas vacías → está en **minutos**.
- **Integridad del JOIN:** las fallas por tipo de máquina suman 4.925, igual que el total de `FactITSLA` → ninguna falla se pierde al cruzar tablas.
- **Bajas:** ninguna máquina tiene fecha de baja vacía, pero la primera es de junio de 2010 → ninguna se dio de baja dentro del período.
- **Altas:** 221 máquinas empezaron a funcionar después del 01/01/2007 → se les cuentan solo las horas desde su inicio.

## Metodología

- **Horas en servicio** de cada máquina: desde el 01/01/2007 (o su fecha de inicio, si fue posterior) hasta el 01/01/2010. Período completo = 26.304 horas.
- **MTBF por tipo** = horas en servicio de **todas** las máquinas del tipo ÷ fallas del tipo. Se calcula por grupo para que las máquinas que nunca fallaron sumen sus horas; si no, el MTBF quedaría subestimado.
- **MTTR** = minutos caídos ÷ fallas.
- **Disponibilidad** = (horas en servicio − horas caídas) ÷ horas en servicio.

## Resultados

| Tipo | Máquinas | Fallas | MTBF (h) | MTTR (min) | Horas caídas | % del tiempo caído | Disponibilidad |
|---|---:|---:|---:|---:|---:|---:|---:|
| POS01 | 2.679 | 3.495 | 20.163 | 72,5 | 4.226 | 64% | 99,9940% |
| POS02 | 102 | 781 | 2.666 | 79,7 | 1.038 | 16% | 99,9502% |
| HUB01 | 460 | 90 | 134.443 | 535,4 | 803 | 12% | 99,9934% |
| WSR01 | 3.040 | 185 | 432.239 | 49,8 | 154 | 2% | 99,9998% |
| WSR02 | 1.060 | 155 | 179.885 | 54,4 | 141 | 2% | 99,9995% |
| RUT01 | 10 | 105 | 2.505 | 65,0 | 114 | 2% | 99,9568% |
| POS03 | 73 | 33 | 25.100 | 141,1 | 78 | 1% | 99,9906% |
| MSR01 | 346 | 80 | 113.765 | 44,3 | 59 | 1% | 99,9994% |
| POS04 | 46 | 1 | — | 22,0 | 0 | 0% | 99,9998% |

**Total:** 6.612 horas de máquina parada en 3 años. MTTR general: 80,6 minutos.

## Conclusiones

**1. POS02 y RUT01 son los tipos menos confiables.**
Cada máquina falla en promedio cada ~2.500–2.700 horas, unos **3,5 meses**. Una POS01 falla cada ~20.000 horas (unos 2,3 años): POS02 y RUT01 fallan **unas 8 veces más seguido**. Son problemas de **confiabilidad** (MTBF bajo), no de reparación: su MTTR es normal.

**2. POS01 concentra el 64% del tiempo caído por volumen, no por mal desempeño.**
Es el tipo con más fallas (3.495) porque hay 2.679 máquinas, pero por máquina su MTBF y su MTTR son razonables. Mirar solo el tiempo caído total lleva a una conclusión equivocada: separar MTBF y MTTR muestra dónde están los problemas reales.

**3. HUB01 tiene un problema de reparación, no de fallas.**
Falla poco (MTBF de 134.443 h), pero cada falla tarda **535 minutos, casi 9 horas**: 6,6 veces el promedio. Si HUB01 es equipamiento de red, cada falla puede dejar sin servicio a otras máquinas de la tienda, y el impacto real sería mayor que sus 803 horas propias.

**4. La disponibilidad es alta en todos los tipos (> 99,95%) y no alcanza para comparar.**
Las diferencias entre tipos aparecen en el MTBF y el MTTR, no en la disponibilidad. Por eso conviene seguir los dos KPIs por separado.

**5. Las estaciones de trabajo (WSR01, WSR02) y MSR01 no requieren acción.**
MTBF alto, MTTR bajo y apenas un 5% del tiempo caído entre los tres.

## Análisis por tipo de falla

**6. Pareto: 4 tipos de falla generan dos tercios del tiempo caído.**
De 54 tipos de falla, casi todos se resuelven en 25–40 minutos. Cuatro se salen de escala:

| Tipo de falla | Fallas | MTTR (min) | Dónde aparece |
|---|---:|---:|---|
| Server | 131 | 732 | 6 tipos de máquina (sobre todo POS01 y POS02) |
| POS | 195 | 598 | Solo cajas (POS01, POS02, POS03) |
| Hub | 90 | 535 | Solo HUB01 |
| Router | 2 | 526 | Solo RUT01 |

Son el **8,5% de las fallas y el 66% del tiempo caído**. Reducir el tiempo de reparación de estos 4 tipos tiene mucho más impacto que mejorar los otros 50.

**7. El MTTR "normal" de POS01 esconde fallas muy largas.**
De las 3.495 fallas de POS01, solo 248 (7%) son de tipo POS o Server, pero duran 9–13 horas cada una y generan el **62% de sus horas caídas**. El resto se resuelve en media hora.

**8. HUB01 tiene una sola forma de fallar.**
Sus 90 fallas son todas de tipo "Hub", con el mismo MTTR de 535 minutos. El problema no es variado: es una reparación que siempre lleva unas 9 horas.

**9. Hipótesis probada y descartada: las fallas de servidor no son caídas compartidas.**
Como las fallas "Server" aparecen en 6 tipos de máquina, se planteó que la caída de un servidor central arrastraba a varias máquinas a la vez. Si fuera así, habría varias fallas Server en la misma tienda al mismo tiempo. Resultado: 0 casos con el mismo horario y 1 solo caso (2 máquinas) en el mismo día, sobre 131 fallas. **Las fallas Server son aisladas**: afectan a una máquina por vez.

## Recomendaciones

| Prioridad | Tipo | Problema | Acción |
|---|---|---|---|
| 1 | POS02, RUT01 | Fallan muy seguido (MTBF bajo) | Mantenimiento preventivo; analizar causas de falla; evaluar reemplazo del modelo |
| 2 | HUB01 | Reparaciones muy lentas (MTTR alto) | Repuestos en stock en tienda, técnico asignado, procedimiento de reparación estándar |
| 3 | POS03 | MTTR del doble del promedio | Revisar el proceso de reparación |
| 4 | POS01 | Pocas fallas muy largas (POS y Server) | Atacar esos dos tipos de falla: concentran el 62% de su tiempo caído |
| 5 | Fallas Server (todas las máquinas) | MTTR de 12 horas, el más alto | Revisar el procedimiento de reparación de servidores; al ser fallas aisladas, la solución está en cada equipo y no en un servidor central |

## Limitaciones

- **POS04** tiene una sola falla: su MTBF y su MTTR no son representativos.
- **RUT01** tiene solo 10 máquinas: el resultado es confiable para esas máquinas, pero la muestra es chica.
- La disponibilidad se calcula sobre 24 h/día. Si las tiendas operan menos horas, la disponibilidad en horario comercial sería algo menor.
- ContosoRetailDW es una base de demostración de Microsoft: los datos son simulados.

## Cómo reproducirlo

1. Restaurar la base **ContosoRetailDW** en SQL Server.
2. Abrir `proyecto_final_MTBF_MTTR.sql` en SSMS y ejecutarlo completo.
   - Sección 1: validación de datos
   - Sección 2: MTTR por tipo
   - Sección 3: tabla final con MTBF, MTTR y disponibilidad
   - Sección 4: análisis por tipo de falla y prueba de hipótesis
