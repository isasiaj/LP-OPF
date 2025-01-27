# Título del Proyecto
Optimización de la topología de
redes eléctricas para minimizar
costes de operación
# Trabajo de Fin de Grado - Ingeniería Eléctrica

Este repositorio contiene el código desarrollado para el Trabajo de Fin de Grado (TFG) del Grado en Ingeniería Eléctrica en la Universidad Politécnica de Madrid (UPM).

El desarrollo de este proyecto tomó como punto de partida el código de un TFG realizado por otro alumno en años anteriores, disponible en el siguiente repositorio: [wbye-OPF](https://github.com/wbye-upm/wbye-OPF).

# Versiones usadas durante el desarrollo

    Julia Version 1.11.1 Commit 8f5b7ca12a (2024-10-16 10:53 UTC)
    [7c4d4715] AmplNLWriter v1.2.2
    [336ed68f] CSV v0.10.15
    [a93c6f00] DataFrames v1.7.0
    [2e9cd046] Gurobi v1.3.1
    [87dc4568] HiGHS v1.10.2
    [b6b21f68] Ipopt v1.6.7
    [4076af6c] JuMP v1.23.3
    [91a5bcdd] Plots v1.40.8
    [c36e90e8] PowerModels v0.21.2
    [229d1e32] PowerPlots v0.4.9
    [08abe8d2] PrettyTables v2.4.0
    [f09e9e23] Couenne_jll v0.500.801+0
    [37e2e46d] LinearAlgebra v1.11.0
    [56ddb016] Logging v1.11.0
    [3fa0cd96] REPL v1.11.0
    [2f01184e] SparseArrays v1.11.0

# Explicación código

Este código ha sido desarollado para el TFG del Grado de Ingería Eléctrica por la UPM. Su función pricipal es la óptimización de la topología en sistemas de transporte de energía eléctrica.

Este código se ejecuta desde el archivo "main.jl", desde el cual se llaman al resto de sus componetes. 

El código se puede dividir en cuatro partes:

* **boot**: Se ejecuta solo al abrir el codigo, hace unas optimizaciones inciales para reducir el tiempo de ejecución de las siguientes optimizaciones.
* **selectEstudio**: Permite al usuario selccionar el sistema que quiere optimizar, el *solver* y las funcionalidades a utilizar durante la optimización.
* **extraerDatos**: Carga los datos de la red selccionada desde los archivo *.csv* presentes en la carpeta `./Casos/`
* **LP_OPF**: Realiza la optimización seleccionada por el usuario.
* **gestorResultados**: Una vez realiza la optmización gestiona los resultados, permientiendo mostralos por pantalla, para redes pequeñas, y almacenarlos.

# Estrcutura de archivos


## Descripción de los directorios

Explicación básica de los diferetes repositorios presentes en este proyecto.

```plaintext
.
├── Casos/
├── Funciones/
├── LP-OPF/
├── Resultados/
├── main.jl
├── .gitignore
├── .gitattributes
└── README.md
```

- **`./Casos/`**: Contiene los datos de entrada utilizados en el proyecto. Explicación detalla dentro del directorio.

- **`./Funciones/`**: Contiene las funciones que necesitan ser vistas desde el archivo `main.jl`.
  - `./sistema_test/`: Sistema usando durante la carga incial.
  - `boot.jl`: Optimización inicial para que el resto de optimizaciones de ejecuten de forma más rápida.
  - `cargarFunciones.jl`: Archivo que lal llamarlo carga el resto de funciones.
  - `cargarLibrerias.jl`: Punto de entrada principal del proyecto.
  - `elegirOpcion.jl`: Función que permite al usuario elegir una opción dentro de una lista de cadenas de texto.
  - `extraerDatos.jl`: Función que carga los datos almacenados en los archivo *.csv* del caso que se le pasé por parámetro
  - `gestorResultados.jl`: Permite mostrar por pantalla los DstaFreme de los resultados de optmización, para redes epqueñas, y almacenarlos en el directorio `./Resultados/`.
  - `limpiarTerminal.jl`: Deja el terminal limpio.
  - `selectEstudio.jl`: Pide al usuario que introduzca por teclado el caso a estudiar, el solver y la optimización que quiere realizar.

- **`LP-OPF/`**: Contiene el código utilizado durante la optimización. Explicación detalla dentro del directorio.

- **`./Resultados/`**: Una vez realiza las optimizaciones, en esta carpeta se guardarn los resultados de éstas:
  - `solAngulos.csv`: Contiene los ángulos de desfase de la tensión en los diferentes nodos del sistema. Las cabeceras de este archivo son el nodo *BUS* y el ángulo de desfase en grados *GRADOS*.
  - `solFlujosLineas.csv`: Guías de usuario.
  - `solGeneradores.csv`: Contiene la potencia optima generada por los diferentes generadores del sistema. Las cabeceras de este archivo son el nodo donde se encuntra *BUS* y potencia generada en MW  *PGEN*.
  - `solLMP.csv`: Contiene los precios marginales locales de la energía en cada nodo del sistema. Las cabeceras de este archivo son el nodo *BUS*, el precio marginal local (€/MW) *LMP*, la componente marginal de energía *MEC* y la componente marginal de congestión *MCC*.

