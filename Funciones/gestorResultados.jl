# Esta función gestiona los DataFrames de la solución de la Optimización
# Entrada
#    Codigo_Fin: Motivo por el que se termino la optimizacion principal 
#    coste_inicial: Coste total con la topología inicial del sistema
#    coste_final: Coste total con la topología final del sistema
#    solGeneradores: DataFrame con la solución de los generadores
#    solFlujos: DataFrame con la solución de los flujos
#    solAngulos: DataFrame con la solución de los ángulos
#    solLMP: DataFrame com la solución de precios marginales locales

function gestorResultados(Codigo_Fin, coste_inicial::Float64, coste_final::Float64, solGeneradores::DataFrame, solFlujos::DataFrame, solAngulos::DataFrame, solLMP::DataFrame)

    # Mostrar resultados en caso de que la optimización se haya realizado de forma exitosa.
    if Codigo_Fin == OPTIMAL || Codigo_Fin == LOCALLY_SOLVED || Codigo_Fin == ITERATION_LIMIT

        if Codigo_Fin == OPTIMAL
            println("Solución óptima encontrada")

        elseif Codigo_Fin == LOCALLY_SOLVED
            println("Solución local encontrada")

        elseif Codigo_Fin == ITERATION_LIMIT
            println("Límite de iteraciones alcanzado")

        end
      
        # Comprueba el número de files de los DataFrames de la solución
        genFilas = DataFrames.nrow(solGeneradores);
        flFilas  = DataFrames.nrow(solFlujos);
        angFilas = DataFrames.nrow(solAngulos);
        lmpFilas = DataFrames.nrow(solAngulos);

        # Asigna el número máximo de filas que se puede mostrar
        nmax = 10

        # En caso de que no se supere el máximo de filas asignado
        if genFilas <= nmax && flFilas <= nmax && angFilas <= nmax && lmpFilas <= nmax

            # Pregunta al usuario si quiere tener los resultados en el terminal
            println("\n¿Quiere imprimir por el terminal el resultado?")
            println("Pulsa la tecla ENTER para confirmar o cualquier otra entrada para negar")
            mostrarTerminal = readline(stdin)

            # En caso que pulse la tecla ENTER
            if mostrarTerminal == ""

                # Muestra las tablas de la solución en el terminal
                println("Solución de los generadores:")
                DataFrames.show(solGeneradores, allrows = true, allcols = true)
                println("\n\nSolución de los flujos:")
                DataFrames.show(solFlujos, allrows = true, allcols = true)
                println("\n\nSolución de los ángulos:")
                DataFrames.show(solAngulos, allrows = true, allcols = true)
                println("\n\nSolución de los ángulos:")
                DataFrames.show(solLMP, allrows = true, allcols = true)

            # En caso de que introduzca cualquier otra entrada
            else
                println("\nNo se imprimirá el resultado")

            end
        
        # En caso de que se supere el máximo de filas en alguno de los DataFrames
        else
            println("\nLas tablas son demasiado grandes para imprimir por el terminal")

        end

        # Imprime en pantalla el coste final que se obtiene tras la optimización
        if coste_inicial == coste_final
            println("\nCoste optimo del sistema: ", round(coste_inicial, digits = 2), " €/h")
        else
            println("\n\nSe ha optimizado la topología reducion el coste total:")
            println(" Coste inicial del sistema: ", round(coste_inicial, digits = 2), " €/h")
            println(" Coste  final  del sistema: ", round(coste_final, digits = 2), " €/h")
        end

        # Pregunta al usuario si quiere guardar los datos en un CSV
        println("\n¿Quiere guardar el resultado en un archivo CSV?")
        println("Pulsa la tecla ENTER para confirmar o cualquier otra entrada para negar")
        guardarCSV = readline(stdin)

        # En caso de que pulse la tecla ENTER
        if guardarCSV == ""

            # Pregunta al usuario si realmente quiere guardar debido a que se sobreescribirá en el fichero existente
            println("Si guardas en CSV se van a borrar los datos guardados anteriormente")
            println("¿Estás seguro de que quieres guardar?")
            println("\nPulsa la tecla ENTER para confirmar o cualquier otra entrada para negar")
            confirmarGuardarCSV = readline(stdin)

            # En caso de que pulse la tecla ENTER
            if confirmarGuardarCSV == ""
                # Guarda en los correspondientes ficheros los resultados obtenidos
                CSV.write("./Resultados/solLMP.csv", solLMP, delim = ";")
                CSV.write("./Resultados/solAngulos.csv", solAngulos, delim = ";")
                CSV.write("./Resultados/solFlujosLineas.csv", solFlujos, delim = ";")
                CSV.write("./Resultados/solGeneradores.csv", solGeneradores, delim = ";")
                println("\nEl resultado se ha guardado en ./Resultados")
            
            else
                # Cualquier otra entrada no se garda el resultado
                println("\nNo se guardará el resultado")

            end
        
        else
            # Cualquier otra entrada no se garda el resultado 
            println("\nNo se guardará el resultado")
            
        end
    
    # En caso de que no se llega a una solución óptima del problema
    else
        println("ERROR: ", Codigo_Fin)
        readline()
    end

end