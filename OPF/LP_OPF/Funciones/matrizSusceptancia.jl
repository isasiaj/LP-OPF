# Esta funcion crea la matriz de susceptancia B con los datos de las líneas

function matrizSusceptancia(datos::DataFrame)

    # Se crea un vector con los valores de la susceptancia de cada línea B = 1/x
    B = 1 ./ (datos.x)

    # Se devuelve la matriz susceptancia
    return B
end