# Funcion donde se elecciona las caracteristicas del estudio al realizar.
# Salida:
#   casoEst:        Sistema seleccionada para su estudio
#   optionLineSW:   Tipo de estudio a relizar sobre el sistema
#   s:              Solver principal a usar durante el estudio

function selectEstudio()

    while true
        # Casos de estudio
        # Carga en el vector "caso" la lista de carpetas que hay en la carpeta de "Casos"
        listaCasos = readdir("Casos")
        # Se carga la lista y el nombre a la función de elegir opción
        casoEst = elegirOpcion(listaCasos, "caso")

        # Elegir el solver que se quiere emplear
        listaOTS = ["No OTS",
                    "OTS simple",
                    "OTS precios con Dif. fnc objetivo 1",
                    "OTS precios con Dif. fnc objetivo 2",
                    "OTS precios con duales"]
        optionLineSW = elegirOpcion(listaOTS, "Optimizar topologia")

        # Elegir el solver que se quiere emplear
        listaSolvers = ["Gurobi", "HiGHS", "Ipopt"]
        s = elegirOpcion(listaSolvers, "solver")

        # Limpieza del terminal
        limpiarTerminal()

        # Imprimir en terminal el resumen de todos las opciones elegidas
        println("Resumen LP-OPF:")
        println("Caso de estudio ----- ", casoEst)
        println("Optimizar topologia - ", string(optionLineSW))
        println("Optimizador --------- ", s)

        # Pregunta al usuario si las opciones anteriores concuerdan con lo que quiere resolver, 
        # en caso negativo puede volver a seleccionar las opciones 
        println("\nPulsa la tecla ENTER para continuar o cualquier otra entrada para volver a elegir.")
        respuesta = readline()
        
        # Si la respuesta es un "ENTER" procede a continuar y devolver dichas opciones
        if respuesta == ""
            return casoEst, optionLineSW, s
        end
        # Cualquier entrada se vuelve a pedir seleccionar otro estudio desde el principio
    
    end

end
