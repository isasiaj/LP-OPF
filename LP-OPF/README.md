# Descripción del directorio

Este directorio contiene las funciones usadas durante la optimización.
# Explicación archivo LP_OPF.jl

La función principal de la optimización está en el archivo `LP_OPF.jl`, y desde ella se llama a las funciones contenidas en `./LP-OPF/Funciones`, dependiendo de la optimización seleccionada. Este código permite realizar diferentes optimizaciones, con distintas funcionalidades.

- **No OTS**: Se realiza un LP-OPF simple, con topología fija.
- **OTS simple**: Se realiza optimización de un LP-OPF con OTS, pero sin calcular precios del servicio de cambio de topología.
- **OTS precios con Dif. fnc objetivo 1**: Se realiza optimización de un LP-OPF con OTS. Los precios del servicio se calculan por diferencia de costes totales de generación, usando como base el valor con la topología inicial.
- **OTS precios con Dif. fnc objetivo 2**: Se realiza optimización de un LP-OPF con OTS. Los precios del servicio se calculan por diferencia de costes totales de generación, usando como base el valor con la topología final, una vez optimizada.
- **OTS precios con duales**: Se realiza optimización de un LP-OPF con OTS. Los precios del servicio de conectar una línea se calculan mediante duales.

# Archivos de datos de la red

- **`LP_OPF.jl`**: Archivo principal que gestiona las optimizaciones a realizar-

- **`Funciones/CalculateServiceOTS_dual.jl`**: Función que calcula el impacto de conectar una línea sobre el coste final mediante los duales.

- **`Funciones/CalculoOPF_LMP.jl`**: Función realiza una optimización LP-OPF, y devuelve las diferentes componentes de los precios marginales.

- **`Funciones/calculoOPF_OTS_BinVar.jl`**: Función que calcula la topología optimiza de la red, con las restricciones dadas.

- **`Funciones/calculoOPF_OTS.jl`**: Función que realiza la optimización LP-OPF con OTS, y devulve los resultados con la topología optima. en esta función se usa la función del archivo `calculoOPF_OTS_BinVar.jl`.

- **`Funciones/calculoOPF.jl`**: Esta función realiza un LP-OPF básico, con cálculo de duales. Es usada en todos los tipos de optimizaciones.

- **`Funciones/gestorDatosLP.jl`**: Función heredada del código anterior, que extrae algunos datos de las estructura de la red, y los guarda en listas específicas.

- **`Funciones/IncializarModelo.jl`**: Se crea el objeto de *JuMP* con el *solver* pasado como parámetro.

- **`Funciones/matrizSusceptancia.jl`**: Devuelve una lista de las susceptancias de las líneas que componen la red.
