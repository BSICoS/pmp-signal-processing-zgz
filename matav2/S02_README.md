# S02_correct_jumps.m

Corrección de saltos residuales en la PPG del MATA y estimación de HR mediante promediado espectral con tracking del máximo en frecuencia (`peakednessCost`).

## Propósito

La PPG del MATA presenta dos artefactos que sobreviven a la lectura inicial:

1. **Saltos finos** (no los de ganancia gruesa, que ya elimina [S01_correct_GAIN_jumps.m](S01_correct_GAIN_jumps.m)) — discontinuidades pequeñas que distorsionan el espectro.
2. **Interferencia espuria a ~75 bpm (1.25 Hz)** que puede aparecer como un pico falso si se estimara el HR por simple búsqueda del máximo espectral.

S02 limpia los saltos restantes y estima el HR de forma robusta frente a esa interferencia, apoyándose en `peakednessCost` (toolbox `biomedical-signal-processing`): un promediado espectral tipo Welch combinado con un tracking continuo del pico que pondera la **agudeza** del mismo, lo cual permite rechazar la interferencia de 1.25 Hz aunque caiga dentro del rango fisiológico.

## Entrada

- `<patientID>.mat` en `dataDir` (por defecto `registros/`), con la variable **`PPG_corrected`** generada por S01.
- Frecuencia de muestreo asumida: `fs = 25.6 Hz`.

## Salida

Se añaden al mismo `.mat` (vía `save -append`):

| Variable | Descripción |
|---|---|
| `PPG_wojumps` | PPG limpia, resampleada a 128 Hz y filtrada paso-alto (0.1 Hz). |
| `HR_PN`  | Heart rate estimado en bpm. |
| `tHR_PN` | Eje temporal (en segundos desde el inicio) asociado a `HR_PN`. |

## Pipeline interno

1. **Carga e interpolación de NaNs** ([líneas 33-44](S02_correct_jumps.m#L33-L44)) — `pchip` sobre huecos puntuales. *Pendiente:* descartar tramos interpolados largos en vez de muestras sueltas.
2. **Detección de saltos** ([líneas 52-71](S02_correct_jumps.m#L52-L71)) — umbral fijo `|diff(PPG)| > 40`.
3. **Marcado como NaN y resampleo** ([líneas 80-90](S02_correct_jumps.m#L80-L90)) — se invalida la muestra posterior al salto y se sube a `fsi = 5·fs = 128 Hz` con spline.
4. **Filtrado paso-alto** ([líneas 92-93](S02_correct_jumps.m#L92-L93)) — `detrend` cuadrático + Chebyshev II orden 4, atenuación 60 dB, corte 0.1 Hz → `PPG_wojumps`.
5. **Filtrado LPD** ([líneas 95-99](S02_correct_jumps.m#L95-L99)) — `LPDFiltering` realza los flancos del pulso (paso de banda derivativo, fpLPD = 7.8 Hz, fcLPD = 8.0 Hz).
6. **Matriz de señales** ([líneas 102-103](S02_correct_jumps.m#L102-L103)) — `[zscore(PPG_wojumps) zscore(LPD)]`, con los primeros y últimos 5 s puestos a NaN para evitar transitorios.
7. **Estimación de HR con `peakednessCost`** ([líneas 106-118](S02_correct_jumps.m#L106-L118)) — promedia espectros de Welch en ventanas y trackea el pico fisiológico:

   | Parámetro | Valor | Rol |
   |---|---|---|
   | `DT`      | 1 s              | Paso entre estimaciones (resolución temporal del HR). |
   | `Ts`      | 10 s             | Longitud de cada periodograma de Welch. |
   | `Tm`      | 10 s             | Longitud de los sub-intervalos para Welch. |
   | `Omega_r` | [40 160]/60 Hz   | Rango de búsqueda de HR (40-160 bpm). |
   | `K`       | 5                | Número de armónicos considerados en el coste. |
   | `d`, `b`, `a` | 0.4, 0.5, 0.7 | Pesos del coste (penaliza picos no agudos / armónicos débiles). |
   | `Nfft`    | 2^12             | Resolución frecuencial. |

8. **Conversión y guardado** ([líneas 128-143](S02_correct_jumps.m#L128-L143)) — `HR_PN = bar_fr·60`, append al `.mat`.

## Cómo ejecutarlo

```matlab
% Desde MATLAB, con el directorio prueba_MATA02 como pwd:
dataDir = 'registros';   % editar dentro del script
S02_correct_jumps
```

Requiere haber corrido antes [S00_read_mata.m](S00_read_mata.m) y [S01_correct_GAIN_jumps.m](S01_correct_GAIN_jumps.m) sobre el mismo `dataDir`. Necesita la toolbox `biomedical-signal-processing` en el path (la añade el propio script desde `OneDrive - unizar.es/DOCTORADO/biomedical-signal-processing`).

## Parámetros sensibles

- **`threshold_new = 40`** ([línea 68](S02_correct_jumps.m#L68)) — calibrado para los datos actuales. Señales con amplitudes muy distintas necesitarán re-calibración. Las líneas comentadas justo encima muestran umbrales adaptativos basados en `mean + k·std` que se probaron y se descartaron.
- **`Omega_r = [40 160]/60`** ([línea 109](S02_correct_jumps.m#L109)) — incluye 75 bpm (1.25 Hz) porque `peakednessCost` rechaza esa interferencia por su forma, no por exclusión de rango. La alternativa comentada `[80 150]/60` la excluiría pero perdería sujetos con bradicardia.
- **`SetupLPD.fpLPD = 7.8`, `fcLPD = 8.0`** — adaptados a la banda útil del pulso a `fsi = 128 Hz`. Si se cambia `fsi`, hay que reajustar.

## Limitaciones conocidas

- No se eliminan tramos interpolados largos, solo muestras sueltas ([línea 49](S02_correct_jumps.m#L49)). En registros con grandes huecos la spline puede introducir artefactos.
- Los bloques `keyboard` están comentados — útil descomentarlos para inspeccionar registros individuales durante el debug.
- El script siempre re-procesa todos los `.mat`; no hay check de "ya procesado" como sí tiene S00.
