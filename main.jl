# Se carga todas las librerías
include("./Funciones/cargarLibrerias.jl")

# Se carga las funciones
include("./Funciones/cargarFunciones.jl")

Logging.disable_logging(Logging.Error)

# Se inicializa el programa con diferentes test
# principalmente para cargar los solvers y resolver con mayor rapidez el caso pedido por el usuario
boot()

# Variable para salir del bucle
finPrograma = false
while !finPrograma

    limpiarTerminal()

    # Se entra en un bucle para que el usuario seleccione el caso que se quiere estudiar
    casoEstudio, optionOTS, solver = selectEstudio()
    limpiarTerminal()

    dLinea, dGen, dNodo, nL, nG, nN, bMVA = extraerDatos(casoEstudio)

    # Una vez elegido el caso de estudio se llama a la función correspondiente para realizar el cálculo del problema de optimización
    println("\nGenerando OPF...")
    Codigo_Fin, coste_inicial, coste_final, solGen, solFlujos, solAngulos, solLMP = LP_OPF(dLinea, dGen, dNodo, nL, nG, nN, bMVA, solver, optionOTS)

    # Gensión de los resultados de optimización
    limpiarTerminal()
    println("Problema resuelto")
    gestorResultados(Codigo_Fin, coste_inicial, coste_final, solGen, solFlujos, solAngulos, solLMP)

    # Preguntar al usuario si quiere continuar en el bucle para estudiar otro caso
    println("\nPulsa la tecla ENTER para continuar o cualquier otra entrada para salir.")
    if readline() == ""
        # Se mantiene la variable en falso para continuar en el bucle
        global finPrograma = false
    else
        # Actualización de la variable para salir del bucle
        global finPrograma = true
    end

end