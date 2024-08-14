function elegirSiNo(tipo::String)
    while true
        # Entra en un bloque try-catch para poder manejar las entradas que provocan excepciones en el sistema
        try
            # Limpia el terminal
            limpiarTerminal()

            println("Quieres usar la funcionalidad ", tipo, "? (y/N):")
            println("\nPulsa la tecla ENTER para continuar o cualquier otra entrada para volver a elegir.")
            respuesta = readline()
            
            # Si la respuesta es un "ENTER" procede a continuar y devolver dichas opciones
            if respuesta == "y" || respuesta == "Y"
                return true
            elseif respuesta == "n" || respuesta == "N"
                return false
            else
                error("")
            end

        catch
            # Limpia el terminal
            limpiarTerminal()
            # El mensaje se muestra en pantalla por 2 segundos
            println("Entrada no válida. Por favor, introduzca una correcta.")
            sleep(2)
            continue

        end
        
    end
end