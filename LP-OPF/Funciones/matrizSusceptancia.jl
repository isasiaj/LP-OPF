# Esta funcion calcula las susceptancias de cada linea.
# Entrada 
#   datos: Estrcutura con los datos de las lineas
# Salida
#   B: Estrutura con las susceptancias de cada linea
function matrizSusceptancia(datos::DataFrame)
    # Se crea un vector con los valores de la susceptancia de cada línea B = 1/x
    B = 1 ./ (datos.x)
    return B
end