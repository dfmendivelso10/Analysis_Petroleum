# Choque petrolero 2022 y subsidios a combustibles fósiles en Latinoamérica

Prueba técnica de economía aplicada. Cuantifica y caracteriza el efecto del choque de
precio internacional del petróleo de 2022 sobre los subsidios a combustibles fósiles en
América Latina, y discute sus implicaciones fiscales para una recomendación de política.

## Pregunta

¿Cómo afectó el choque de precios del petróleo de 2022 a los subsidios a combustibles
fósiles en LATAM, y qué implica para la política fiscal y de subsidios?

## Fuentes de datos

- **IMF Fossil Fuel Subsidies Database** (obligatoria): subsidios explícitos e implícitos.
- **EIA**: precio internacional del petróleo Brent.
- **FMI, World Economic Outlook** (vía IMF DataMapper): indicadores fiscales (deuda pública
  bruta, balance fiscal, ingreso del gobierno general). Se usa el WEO y no el Banco Mundial
  porque cubre los 34 países sin missing values (el Banco Mundial deja 50–79 % de missing values en el Caribe).

Descargadas como referencia pero no integradas al panel: riesgo país EMBIG (BCRP) y
reservas internacionales (World Bank). El detalle de cada fuente, con URL y motivo de
inclusión o exclusión, está en `data/raw/FUENTES.md`.

## Estructura

```
code/            config.R + modelo (06), pieza fiscal (07) y robustez (08)
code/limpieza/   descarga, procesamiento, validación y diccionario
code/descriptivas/  tablas y figuras descriptivas (01–05)
data/raw/        Fuentes crudas sin modificar (IMF .xlsb, Brent, fiscal WEO)
data/processed/  Paneles limpios (.xlsx)
outputs/         figures/ y tables/
docs/            Pieza de comunicación final
```

## Reproducir

Requiere **Python 3** (datos) y **R 4.4+** (análisis). Desde la raíz del proyecto:

```bash
# Dependencias (una vez)
pip install pyxlsb pandas openpyxl requests
Rscript -e 'install.packages(c("here","tidyverse","readxl","writexl","openxlsx","patchwork","fixest","sandwich","lmtest"))'

# 1) Descargar fuentes complementarias (precio Brent y datos fiscales)
python3 code/limpieza/00a_descargar_brent.py
python3 code/limpieza/00b_descargar_fiscal.py
# Opcionales (descargadas pero no integradas al panel; ver data/raw/FUENTES.md)
python3 code/limpieza/00d_descargar_riesgo.py     # riesgo país EMBIG
python3 code/limpieza/00e_descargar_reservas.py   # reservas internacionales

# 2) Procesamiento: IMF + Brent + fiscal -> paneles en data/processed/  (~9 s)
python3 code/limpieza/00c_procesar.py
python3 code/limpieza/01_variables.py
python3 code/limpieza/02_validar.py

# 3) Descriptivas en R (tablas y figuras; leen los paneles .xlsx)
Rscript code/descriptivas/01_tabla_resumen.R   # Tabla 1: descriptiva por grupo
Rscript code/descriptivas/02_tabla_paises.R    # Tabla 2: clasificación de los 34 países
Rscript code/descriptivas/03_fig_ruptura.R     # Figura 1: ruptura 2022
Rscript code/descriptivas/04_fig_brent.R       # Figura 2: co-movimiento Brent
Rscript code/descriptivas/05_fig_impacto.R     # Figura 3: cambio por país

# 4) Modelo y análisis en R
Rscript code/06_modelo.R       # DiD/TWFE: efecto central + event study (Tabla 4, Figura 4)
Rscript code/07_pieza_fiscal.R # matriz subsidio–deuda y recomendación (Tabla 5, Figura 5)
Rscript code/08_robustez.R     # leave-one-out y exclusión de extremos (Tabla 6)
```

El procesamiento está en Python (pyxlsb) porque leer el `.xlsb` del IMF en R es
prohibitivamente lento; el análisis es 100% R. Todos los outputs se regeneran desde
`data/raw/`.

## Convenciones visuales

Las figuras siguen la paleta del **World Bank Data Visualization Style Guide**
(https://wbg-vis-design.vercel.app/, paquetes `wbpyplot` / `wbplot`), con tipografía
Times New Roman. Las tablas siguen un estándar tipo AER (Times New Roman, solo líneas
horizontales, notas al pie de corrido). Ambos se definen de forma centralizada en
`code/config.R` y se documentan en `docs/convenciones.md`.

## Uso de inteligencia artificial

Para la elaboración de esta prueba se utilizó **Claude Code (Anthropic)** como asistente
de apoyo en tres tareas específicas: (i) validación de datos y consistencia numérica entre
el panel procesado y los resultados reportados; (ii) producción de tablas en formato AER
mediante scripts en R; y (iii) construcción y edición de la presentación en Beamer, con
compilación iterativa para verificar ausencia de errores. En todos los casos, las decisiones
metodológicas —elección del estimador, clasificación de países, variables de resultado y
estrategia de identificación— fueron tomadas bajo criterio del autor.

La carpeta `.claude/` documenta cómo se configuró la asistencia. Contiene:

- `.claude/rules/` — instrucciones que definen estándares de código, econometría, tablas y
  redacción académica que el asistente debía respetar en cada tarea.
- `.claude/agents/` — revisores especializados (código R, econometría, proofreading) que se
  ejecutaban sobre los scripts y slides antes de reportar un resultado como terminado.
- `.claude/skills/` — rutinas reutilizables para tareas recurrentes (compilar LaTeX, correr
  el análisis, hacer commits).

## Entregables

1. Datos — `data/`
2. Código de procesamiento — `code/limpieza/`
3. Código de análisis — `code/descriptivas/`, `code/04_model.R`
4. Comunicación de resultados — `Prueba_Tecnica_Completa/`
