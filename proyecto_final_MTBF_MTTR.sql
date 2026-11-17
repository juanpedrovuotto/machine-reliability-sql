/* ======================================================================
   ANALISIS DE CONFIABILIDAD DE MAQUINAS - CONTOSO RETAIL (2007-2009)
   ----------------------------------------------------------------------
   Autor:   Juan
   Fecha:   11/2026
   Base:    ContosoRetailDW (SQL Server)
   Tablas:  FactITSLA     -> una fila por falla (maquina, inicio, fin, minutos caidos)
            DimMachine    -> catalogo de maquinas (tipo, fecha de inicio de servicio, baja)
            DimOutage     -> catalogo de tipos de falla

   Preguntas:
     1. Cada cuanto falla cada tipo de maquina?            -> MTBF
     2. Cuanto se tarda en reparar cada tipo?               -> MTTR
     3. Que porcentaje del tiempo estuvo funcionando?       -> Disponibilidad
     4. Donde conviene poner el foco de mantenimiento?

   Definiciones:
     MTBF (h)         = horas en servicio de TODAS las maquinas del tipo / fallas del tipo
                        (por grupo: las maquinas que nunca fallaron suman horas)
     MTTR (min)       = minutos caidos / fallas
     Disponibilidad % = (horas en servicio - horas caidas) / horas en servicio * 100
   ====================================================================== */

USE ContosoRetailDW;
GO


/* ======================================================================
   1. VALIDACION DE DATOS
   ====================================================================== */

-- 1.1 Cantidad de fallas y periodo cubierto
--     Resultado: 4.925 fallas, del 2007-01-01 al 2009-12-31 (3 anios completos).
SELECT COUNT(*)             AS fallas,
       MIN(OutageStartTime) AS primer_inicio,
       MAX(OutageStartTime) AS ultimo_inicio,
       MAX(OutageEndTime)   AS ultimo_fin
FROM FactITSLA;


-- 1.2 Unidad de DownTime
--     DownTime no indica su unidad. Se compara con la diferencia en minutos entre
--     inicio y fin. Resultado: 0 filas distintas -> DownTime esta en MINUTOS y es
--     consistente en toda la tabla (sin fines vacios).
WITH control AS (
    SELECT DATEDIFF(MINUTE, OutageStartTime, OutageEndTime) - DownTime AS diferencia
    FROM FactITSLA
)
SELECT COUNT(*) AS filas_que_no_coinciden
FROM control
WHERE diferencia <> 0 OR diferencia IS NULL;


-- 1.3 Maquinas totales vs maquinas con al menos una falla, por tipo
--     LEFT JOIN para no perder las maquinas que nunca fallaron.
--     COUNT(DISTINCT) porque despues del JOIN cada maquina aparece una vez por falla.
--     Resultado: 7.816 maquinas, 2.553 con fallas (33%).
SELECT m.MachineType                AS tipo,
       COUNT(DISTINCT m.MachineKey) AS maquinas,
       COUNT(DISTINCT f.MachineKey) AS maquinas_con_fallas
FROM DimMachine m
LEFT JOIN FactITSLA f ON f.MachineKey = m.MachineKey
GROUP BY m.MachineType
ORDER BY maquinas DESC;


-- 1.4 Fechas de servicio
--     Ninguna maquina tiene DecommissionDate vacia; la primera baja es de 2010-06-16,
--     posterior al periodo -> ninguna se dio de baja entre 2007 y 2009.
--     221 maquinas empezaron despues del 2007-01-01 -> se les cuentan menos horas.
SELECT MIN(ServiceStartDate) AS primer_inicio_servicio,
       MAX(ServiceStartDate) AS ultimo_inicio_servicio,
       MIN(DecommissionDate) AS primera_baja,
       MAX(DecommissionDate) AS ultima_baja,
       SUM(CASE WHEN ServiceStartDate > '2007-01-01' THEN 1 ELSE 0 END) AS empezaron_en_el_periodo
FROM DimMachine;


/* ======================================================================
   2. MTTR POR TIPO DE MAQUINA
   ----------------------------------------------------------------------
   JOIN comun: para el MTTR solo importan las maquinas que fallaron.
   DownTime * 1.0 -> evita que el AVG de enteros corte los decimales.
   Control: la suma de fallas da 4.925 = COUNT(*) de FactITSLA.
   MTTR general: 80,55 minutos.
   ====================================================================== */
SELECT m.MachineType                            AS tipo,
       COUNT(*)                                 AS fallas,
       ROUND(AVG(f.DownTime * 1.0), 1)          AS mttr_min,
       ROUND(SUM(f.DownTime) / 60.0, 0)         AS horas_caidas
FROM FactITSLA f
JOIN DimMachine m ON m.MachineKey = f.MachineKey
GROUP BY m.MachineType
ORDER BY mttr_min DESC;


/* ======================================================================
   3. TABLA FINAL: MTBF, MTTR Y DISPONIBILIDAD POR TIPO
   ----------------------------------------------------------------------
   Horas en servicio de cada maquina: desde el 2007-01-01 (o su fecha de inicio,
   si empezo despues) hasta el 2010-01-01. Periodo completo = 26.304 horas.
   Control: los tipos sin maquinas tardias dan exacto maquinas x 26.304.
   ====================================================================== */
WITH horas AS (
    SELECT MachineType,
           COUNT(*) AS maquinas,
           SUM(DATEDIFF(HOUR,
                        CASE WHEN ServiceStartDate > '2007-01-01' THEN ServiceStartDate
                             ELSE '2007-01-01' END,
                        '2010-01-01')) AS horas_servicio
    FROM DimMachine
    GROUP BY MachineType
),
fallas AS (
    SELECT m.MachineType,
           COUNT(*)        AS fallas,
           SUM(f.DownTime) AS minutos_caidos
    FROM FactITSLA f
    JOIN DimMachine m ON m.MachineKey = f.MachineKey
    GROUP BY m.MachineType
)
SELECT h.MachineType                                                        AS tipo,
       h.maquinas,
       fa.fallas,
       h.horas_servicio,
       CAST(h.horas_servicio * 1.0 / fa.fallas AS DECIMAL(12,0))            AS mtbf_horas,
       CAST(fa.minutos_caidos * 1.0 / fa.fallas AS DECIMAL(12,1))           AS mttr_min,
       CAST(fa.minutos_caidos / 60.0 AS DECIMAL(12,0))                      AS horas_caidas,
       CAST(100.0 * (h.horas_servicio - fa.minutos_caidos / 60.0)
            / h.horas_servicio AS DECIMAL(8,4))                             AS disponibilidad_pct
FROM horas h
LEFT JOIN fallas fa ON fa.MachineType = h.MachineType
ORDER BY horas_caidas DESC;

/* Resultado:
   tipo   maquinas  fallas  horas_servicio  mtbf_h   mttr_min  horas_caidas  disp_%
   POS01    2.679   3.495     70.468.416    20.163     72,5       4.226     99,9940
   POS02      102     781      2.082.432     2.666     79,7       1.038     99,9502
   HUB01      460      90     12.099.840   134.443    535,4         803     99,9934
   WSR01    3.040     185     79.964.160   432.239     49,8         154     99,9998
   WSR02    1.060     155     27.882.240   179.885     54,4         141     99,9995
   RUT01       10     105        263.040     2.505     65,0         114     99,9568
   POS03       73      33        828.312    25.100    141,1          78     99,9906
   MSR01      346      80      9.101.184   113.765     44,3          59     99,9994
   POS04       46       1        186.288   186.288     22,0           0     99,9998  (1 falla: no representativo)
*/


/* ======================================================================
   4. ANALISIS POR TIPO DE FALLA
   ====================================================================== */

-- 4.1 Fallas y MTTR por tipo de falla
--     Control: 54 tipos de falla que suman 4.925.
--     Resultado: casi todos duran entre 25 y 40 min. Cuatro se salen de escala:
--       Server 131 fallas / 732 min | POS 195 / 598 | Hub 90 / 535 | Router 2 / 526
--     PARETO: esos 4 tipos son el 8,5% de las fallas y el 66% del tiempo caido.
SELECT o.OutageType                       AS tipo_falla,
       COUNT(*)                           AS fallas,
       ROUND(AVG(1.0 * f.DownTime), 1)    AS mttr_min
FROM FactITSLA f
JOIN DimOutage o ON o.OutageKey = f.OutageKey
GROUP BY o.OutageType
ORDER BY mttr_min DESC;


-- 4.2 De que maquinas son las fallas largas? (cruce tipo de maquina x tipo de falla)
--     Resultado:
--       Hub    -> solo HUB01 (todas sus 90 fallas son de este tipo).
--       POS    -> solo cajas: POS01 158, POS02 32, POS03 5.
--       Server -> 6 tipos de maquina: POS01 90, POS02 24, WSR01 5, WSR02 5, RUT01 5, MSR01 2.
--       Router -> RUT01 2.
SELECT m.MachineType                      AS tipo_maquina,
       o.OutageType                       AS tipo_falla,
       COUNT(*)                           AS fallas,
       ROUND(AVG(1.0 * f.DownTime), 1)    AS mttr_min
FROM FactITSLA f
JOIN DimMachine m ON m.MachineKey = f.MachineKey
JOIN DimOutage  o ON o.OutageKey  = f.OutageKey
WHERE o.OutageType IN ('Server', 'POS', 'Hub', 'Router')
GROUP BY m.MachineType, o.OutageType
ORDER BY mttr_min DESC;


-- 4.3 Hipotesis: "se cae un servidor central y arrastra a varias maquinas"
--     Si fuera cierto, habria varias fallas Server en la misma tienda al mismo tiempo.
--     a) Mismo inicio y fin exactos: 0 casos.
--     b) Misma tienda y mismo dia: 1 caso (tienda 71, 2009-12-01, 2 maquinas) de 131 fallas.
--     -> HIPOTESIS DESCARTADA: las fallas Server son aisladas, una maquina por vez.
SELECT f.StoreKey,
       CAST(f.OutageStartTime AS DATE)    AS dia,
       COUNT(*)                           AS maquinas_afectadas
FROM FactITSLA f
JOIN DimOutage o ON o.OutageKey = f.OutageKey
WHERE o.OutageType = 'Server'
GROUP BY f.StoreKey, CAST(f.OutageStartTime AS DATE)
HAVING COUNT(*) > 1
ORDER BY maquinas_afectadas DESC;
