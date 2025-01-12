# Bucle que duvuelve la opción que usuario elija dentro de una lista, una vez confirmada la elección
# Entrada
#   o:    Lista de string con el texto de las diferentes opciones.
#   tipo: Texto para mostrar que eleccion tiene que tomar el usuario
# Salida
#   return: Se devulve el texto de la opcion elegida
function elegirOpcion(o::Vector{String}, tipo::String)

    # Inicialización de las variables
    valido = false  # Es la variable designada para ver si la elección es válida, si se da el caso se vuelve true
    seleccion = 0   # Es la opción elegida por el usuario

    while !valido 

        try
            # Limpia el terminal
            limpiarTerminal()

            # Imprimir en el terminal las posibles opciones enumeradas
            for (i, k) in enumerate(o)
                println("$i. $k")
            end

            # Pregunta al usuario que introduzca en el terminal su opción
            println("\nElije el número del ", tipo, " que quiera utilizar: ")
            seleccion = parse(Int, readline())

            # Si la entrada es un número y está dentro del rango de las posibles opciones
            if seleccion >= 1 && seleccion <= length(o)

                limpiarTerminal()
                println("Ha elegido la opción:\n", seleccion, ". ", o[seleccion])
                println("\nPulsa la tecla ENTER para continuar o cualquier otra entrada para volver a elegir.")
                confirmar = readline()
                
                if confirmar == ""
                    #Entrada la tecla ENTER, se sale del bucle
                    valido = true
                else
                    valido = false # Se ignora la entrada y se vuelve a empezar el bucle
                end

            else # Número introducido esté fuera de rango
                limpiarTerminal()
                println("Por favor, introduzca un número entre 1 y $(length(o)).")
                sleep(2)
                valido = false
            end

        # En caso de que la entrada cause una excepción, 
        # por ejemplo introduciendo una letra al cual no se puede convertir en un int
        catch

            # Limpia el terminal
            limpiarTerminal()

            # El mensaje se muestra en pantalla por 2 segundos
            println("Entrada no válida. Por favor, introduzca un número.")
            sleep(2)
            valido = false
        end

    end

    return o[seleccion]
end