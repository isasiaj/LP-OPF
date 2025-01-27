# Descripción del directorio

Aquí se almacenan los que casos que podrán ser elegidos para calcular su OPF durante la ejecución de código.

Estos casos se almacenan en carpetas separadas, donde se encuentran los archivos de los datos de la red. El nombre que se ponga a la carpeta es que se saldrá a la hora de seleccionar la red.
# Archivos de datos de la red

Los datos de la red tienen que estar almacenados en 3 archivos *.csv*, algunos de las columnas presentes en estos archivos no se utilizan, están presentes ya que algunos de ellos parten de casos extraídos de [pglib-opf](https://github.com/power-grid-lib/pglib-opf/tree/master). Se enumeran los archivos y sus columnas utilizadas:

- **`datosGeneradores.csv`**: Contiene los datos de los generadores presentes en la red. 
  - **bus**: Nodo donde está situado el generador.
  - **status**: Variable binaria del estado del calculador, 1 disponible y 0 no está disponible para generar durante la optimización.
  - **Pmax**: Potencia activa máxima que puede generar en MW.
  - **Pmin**: Potencia activa mínima que puede generar en MW, si es distinto de cero el generador siempre está en uso, generar como mínimo esta potencia independientemente del precio de generación.  
  - **c2**: Precio marginal de generación de segundo orden en €/MW<sup>2</sup>, va multiplicado por la potencia al cuadrado.
  - **c1**: Precio marginal de generación de primer orden, en €/MW.
  - **c0**: Coste fijo del generador en €, se cobrará siempre que esté disponible, aunque su generación se a 0 MW. Recomendado valor cero.


- **`datosLineas.csv`**: Contiene los datos de las líneas que componen la red.
  - **fbus**: Nodo origen de la línea.
  - **tbus**: Nodo destino de la línea.
  - **x**: Impedancia de la línea en partes por unidad.
  - **rateA**: Flujo de potencia activa máximo que puede circular por la línea.
  - **status**: Estado inicial de la línea.
  - **fixed**: Variable binaría que indica si el estado de la línea se mantendrá fijo al realizar una optimización de la topología. Si es 1 la línea conservara su estado inicial, aunque conmutarla redujera el coste total de generación. No es necesario añadirla si no existe esta restricción en ninguna de las líneas.

- **`datosNodos.csv`**: Los datos de los nodos que componen la red:
  - **bus_i**: Número de identificación del nodo.
  - **Pd**: Potencia activa demandad en este nodo en MW.

