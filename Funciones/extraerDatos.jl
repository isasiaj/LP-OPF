# Se extrae los datos del caso de estudio
# Entrada
#   c: Nombre del caso elegido del que exter los datos
#
# Salida
#   datosLinea:     datos de las líneas
#   datosGenerador: datos de los generadores
#   datosNodo:      datos de los nodos y la demanda en estos
#   nLineas:        número de lineas en el sistema 
#   nGenerador:     número de gneradores
#   nNodos:         número de nodos
#   bMVA:           potencia base
#   ruta:           ruta al archivo .m del caso, si no hay se devulve "None"
function extraerDatos(c::String)
    println("\nExtrayendo datos...")
    # Datos de las lineas
    datosLinea = CSV.read("Casos/$c/datosLineas.csv", DataFrame)

    # Datos de los generadores
    datosGenerador = CSV.read("Casos/$c/datosGeneradores.csv", DataFrame)

    # Datos de la demanda
    datosNodo = CSV.read("Casos/$c/datosNodos.csv", DataFrame)

    # Número de líneas
    nLineas = size(datosLinea, 1)

    # Número de líneas
    nGenerador = size(datosGenerador, 1)

    # Número de nodos
    nNodos = maximum([datosLinea.fbus; datosLinea.tbus])

    # Potencia base
    bMVA = 100

    # Ruta al archivo .m
    rutaArchivoM = "Casos/$c/$c.m"

    if isfile(rutaArchivoM)
        ruta = rutaArchivoM
    else
        ruta = "None"
    end
    println("Datos extraídos.")
    # Devuelve todos los DataFrames y variables generadas
    return(datosLinea, datosGenerador, datosNodo, nLineas, nGenerador, nNodos, bMVA, ruta)
end