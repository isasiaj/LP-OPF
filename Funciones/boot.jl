# Esta función inicializa todos los solvers para que las próximas veces sean más rápidas

function boot()

    println("Iniciando tests...")
    # Se extrae los datos del sistema_test
    test_linea = CSV.read("Funciones/sistema_test/datosLineas.csv", DataFrame)
    test_generador = CSV.read("Funciones/sistema_test/datosGeneradores.csv", DataFrame)
    test_nodos = CSV.read("Funciones/sistema_test/datosNodos.csv", DataFrame)

    # Con esta red simple se genera una los diferentes OPF para que ya estén cargados cuando el usuario los utilice
    println("Test 1...")
    LP_OPF(test_linea, test_generador, test_nodos, 1, 1, 2, 1, "Gurobi", false, false)

    limpiarTerminal()

    println("Test1 - Completado")
    println("Test 2...")
    LP_OPF(test_linea, test_generador, test_nodos, 1, 1, 2, 1, "HiGHS", false, false)

    limpiarTerminal()

    println("Test 1 - Completado")
    println("Test 2 - Completado")
    println("Test 3...")
    LP_OPF(test_linea, test_generador, test_nodos, 1, 1, 2, 1, "Ipopt", false, false)

    limpiarTerminal()

    println("Test 1 - Completado")
    println("Test 2 - Completado")
    println("Test 3 - Completado")
    println("Test 4...")
    AC_OPF(test_linea, test_generador, test_nodos, 2, 1, 1, "Ipopt")

    limpiarTerminal()

    println("Test 1 - Completado")
    println("Test 2 - Completado")
    println("Test 3 - Completado")
    println("Test 4 - Completado")
    println("Test 5...")
    AC_OPF(test_linea, test_generador, test_nodos, 2, 1, 1, "Couenne")

    limpiarTerminal()
    
    println("Test 1 - Completado")
    println("Test 2 - Completado")
    println("Test 3 - Completado")
    println("Test 4 - Completado")
    println("Test 5 - Completado")
    sleep(1)
    
end
