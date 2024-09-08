function selectEstudio()

    while true
        # Casos de estudio
        # Carga en el vector "caso" la lista de carpetas que hay en la carpeta de "Casos"
        listaCasos = readdir("Casos")
        # Se carga la lista y el nombre a la función de elegir opción
        casoEst = elegirOpcion(listaCasos, "caso")

        # Lista de las opciones del tipo de OPF que se puede usar
        listaOPF = ["LP-OPF", "AC-OPF"]
        opfTip = elegirOpcion(listaOPF, "tipo de OPF")

        # Calcular o no precios marginales locales
        optionLPM = elegirSiNo("LPM")

        if opfTip ==  "LP-OPF"
            # Optimizar o no la topología de la red
            optionLineSW = elegirSiNo("Optimizar topologia")
        end

        # Según el tipo de OPF elegido, se pregunta el solver que se quiere emplear
        if opfTip == "LP-OPF"
            listaACSolvers = ["Gurobi", "HiGHS", "Ipopt"]
            s = elegirOpcion(listaACSolvers, "solver")

        elseif opfTip == "AC-OPF"
            listaACSolvers = ["Ipopt", "Couenne"]
            s = elegirOpcion(listaACSolvers, "solver")
            
        end

        # Limpieza del terminal
        limpiarTerminal()


        # Según el tipo de OPF elegido
        if opfTip == "LP-OPF"
            # Imprimir en terminal el resumen de todos las opciones elegidas
            println("Resumen:")
            println("Caso de estudio ----- ", casoEst)
            println("Tipo de OPF --------- ", opfTip)
            println("Calculo LPM --------- ", string(optionLPM))
            println("Optimizar topologia - ", string(optionLineSW))
            println("Optimizador --------- ", s)

        elseif opfTip == "AC-OPF"
            # Imprimir en terminal el resumen de todos las opciones elegidas
            println("Resumen:")
            println("Caso de estudio ----- ", casoEst)
            println("Tipo de OPF --------- ", opfTip)
            println("Optimizador --------- ", s)
        end

        # Pregunta al usuario si las opciones listados anteriormente concuerdan con lo que quiere resolver, 
        # en caso negativo puede volver a seleccionar las opciones 
        println("\nPulsa la tecla ENTER para continuar o cualquier otra entrada para volver a elegir.")
        respuesta = readline()
        
        # Si la respuesta es un "ENTER" procede a continuar y devolver dichas opciones
        if respuesta == ""


            # Según el tipo de OPF elegido
            if opfTip == "LP-OPF"
                return casoEst, opfTip, optionLPM, optionLineSW, s

            elseif opfTip == "AC-OPF"
                return casoEst, opfTip, false, false, s
            end
        end
        # En caso de introducir cualquier entrada, procede a cancelar y volver a seleccionar las opciones¡
    
    end

end