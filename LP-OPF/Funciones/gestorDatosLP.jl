
function gestorDatosLP(Generador::DataFrame, Demanda::DataFrame, nN::Int, bMVA::Int)

    # El Dataframe introducido como argumento "dGen" en "Generador" contiene los datos de los generadores sacado de su correspondiente archivo "datosGeneradores.csv"
    # R = sparsevec(I, V, n) se crea la lista "R" cuyos índices es el vector "I" y los valores es el vector "V", 
    # cuyo tamaño total es de "n" elementos. Es decir, R[I[k]] = V[k] para k <= n
    # P_Cost es un sparsevec de "nn" elementos que recoge como 
        # Ínidices: nodo en el que están los generadores "Generador.bus"
        # Valores: coste de los respectivos generadores "Generador.P_COSTE"
    # Esto significa que la lista vacía de "nn" elementos se va llenando con los valores del coste en las posiciones del bus correspondiente
    # Por ejemplo: Si hay un generador en el bus 3 que cuesta 10€/MWh, la lista para los elementos 1 y 2 sigen vacíos y el elemento 3 se le asigna un 10
    P_Cost0 = Generador.c0
    P_Cost1 = Generador.c1
    P_Cost2 = Generador.c2

    # P_Gen_lb y P_Gen_ub son sparsevec de "nn" elementos de los limites inferior y superior, respectivamente, de la potencia activa de los gerneradores
        # Índices: nodo donde está el generador "Generador.bus"
        # Valores: límite inferior "Generador.P_MIN" o superior "Generador.P_MAX" del generador
    P_Gen_lb = Generador.Pmin/bMVA
    P_Gen_ub = Generador.Pmax/bMVA

    # En los datos de los generadores se tiene en cuenta generadores que no están activos con status = 0
    # Por lo que se crea un sparsevec que contenga estos valores para considerar generadores apagados
    Gen_Status = Generador.status

    # El Dataframe introducido como argumento "dDem" en "Demanda" contiene los datos de la demanda sacado de su correspondiente archivo "datosNodos.csv"
    # P_Demand es un sparsevec de "nN" elementos donde se recoge como 
        # Índices: nodos donde está la demanda "Demanda.bus_i"
        # Valores: demanda en los respectivos nodos "Demanda.Pd"
    P_Demand = SparseArrays.sparsevec(Demanda.bus_i, Demanda.Pd/bMVA, nN)

    # Se devuelve como resultado de la función todos los SparseArrays generados
    return P_Cost0, P_Cost1, P_Cost2, P_Gen_lb, P_Gen_ub, Gen_Status, P_Demand

end