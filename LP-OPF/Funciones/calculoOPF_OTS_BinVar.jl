function calculoOPF_BinVar(solver::String, dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nL::Int, nG::Int,nN::Int, bMVA::Int, fixed_lines::Vector{Bool})
    # Crear objeto modelo de optimizacion
    modelo = IncializarModelo(solver)
    ########## GESTIÓN DE DATOS ##########
    P_Cost0, P_Cost1, P_Cost2, P_Gen_lb, P_Gen_ub, Gen_Status, P_Demand = gestorDatosLP(dGen, dNodo, nN, bMVA)

    # Array de susceptancias de las líneas
    B = matrizSusceptancia(dLinea)
    
    ########## VARIABLES ##########
    # Se asigna una variable de generación para todos los generadores y se le asigna un valor inicial de 0 
    @variable(modelo, P_G[ii in 1:nG], start = 0)

    # Se considera que el módulo del voltaje en todos los nodos es la unidad y es invariante, V = 1
    # Lo único que varía es el ángulo
    @variable(modelo, θ[1:nN], start = 0)

    # El flujo por la línea que conecta los nodos i-j es igual de la susceptancia de la línea por la diferencia 
    # de ángulos entre los nodos i-j
    # Pᵢⱼ = Bᵢⱼ · (θᵢ - θⱼ)
    @variable(modelo, Pₗᵢₙₑ[ii in 1:nL], start = 0)

    # Variable binaria que controla si una linea está o no activa.
    # Funciona como un interruptor que conecta y desconecta lineas.
    @variable(modelo, Ls[ii in 1:nL], Bin,  start = 1)

    ########## FUNCIÓN OBJETIVO ##########
    # El objetivo del problema es reducir el coste total que se calcula como ∑cᵢ·Pᵢ
    # Siendo:
    #   cᵢ el coste del Generador en el nodo i
    #   Pᵢ la potencia generada del Generador en el nodo i
    Coste_generacion = sum((P_Cost0[ii] + P_Cost1[ii] * P_G[ii] * bMVA + P_Cost2[ii] * (P_G[ii] * bMVA)^2) for ii in 1:nG; init=0)
    penalizacion_cerrar = 0.001* sum(((dLinea.status[ii] - Ls[ii])) for ii in 1:nL if dLinea.status[ii] == 1; init=0)
    penalizacion_abrir = 0.001 * sum((Ls[ii]) for ii in 1:nL if dLinea.status[ii] == 0; init=0)
    @objective(modelo, Min, Coste_generacion + penalizacion_cerrar + penalizacion_abrir)


    ########## RESTRICCIONES ##########
    # Restricción de la relación entre los nodos: PGenᵢ - PDemᵢ = ∑(Pᵢⱼ) - ∑(Pⱼᵢ)
    # Siendo 
    # P_G[ii] la potencia generada en el nodo ii
    # P_Demand[ii] la potencia demandada en el nodo ii
    # En la parte izquierda es el balance entre Potencia Generada menos Potencia Demandada
    # en caso de ser positivo significa que es un nodo que suministra potencia a la red 
    # y en caso negativo, consume potencia de la red
    # Y en la parte derecha es la función del flujo hacia la red
    # Se multiplica a ambos lados por bMVA para asegurar que a la hora de calcular el dual quede con unidades
    node_power_balance = []
    for ii in 1:nN
        local_node_power_balance = @constraint(modelo, (sum(P_G[jj] for jj in 1:nG if dGen.bus[jj] == ii ) - P_Demand[ii])*bMVA == (sum(Pₗᵢₙₑ[jj] for jj in 1:nL if dLinea.fbus[jj] == ii ) - sum(Pₗᵢₙₑ[jj] for jj in 1:nL if dLinea.tbus[jj] == ii ))*bMVA)
        push!(node_power_balance, local_node_power_balance)
    end

    # Restricción de potencia máxima por la línea
    # Su valor abosoluto debe ser menor que el dato de potencia max en dicha línea "dLinea.rateA"
    @constraint(modelo, [ii in 1:nL], Pₗᵢₙₑ[ii] >= -(dLinea.rateA[ii] / bMVA) * Ls[ii])
    @constraint(modelo, [ii in 1:nL], Pₗᵢₙₑ[ii] <=  (dLinea.rateA[ii] / bMVA) * Ls[ii])

    # Restriccion de la potencia que circula por las lineas segun las leyes de kirchhoff simplificadas, para el calculo de LP-OPF.
    # B[ii] susceptancia de la linea que conecta los nodos fbus[ii] - tbus[ii]
    # θ[ii] ángulo del nodo ii
    # Siendo la potencia que circula en la linea que conecta los nodos i-j: Pᵢⱼ = Bᵢⱼ·(θᵢ-θⱼ) 
    @constraint(modelo, [ii in 1:nL], Pₗᵢₙₑ[ii] <= B[ii] * (θ[dLinea.fbus[ii]] - θ[dLinea.tbus[ii]] + pi/3*(1 - Ls[ii])))
    @constraint(modelo, [ii in 1:nL], Pₗᵢₙₑ[ii] >= B[ii] * (θ[dLinea.fbus[ii]] - θ[dLinea.tbus[ii]] - pi/3*(1 - Ls[ii])))

    # Si la linea no está disponible su varible Ls será cero, para asegurar que queda fuera del OPF.
    for ii in 1:nL
        if  fixed_lines[ii] == true
            @constraint(modelo, Ls[ii] == dLinea.status[ii])
        end
    end

    # Restricción de potencia mínima y máxima de los generadores
    @constraint(modelo, [ii in 1:nG], P_Gen_lb[ii] * Gen_Status[ii] <= P_G[ii] <= P_Gen_ub[ii] * Gen_Status[ii])

    # Se selecciona el nodo 1 como nodo de refenrecia
    # Necesario en caso de HiGHS para evitar un bucle infinito al resolver la optimización
    @constraint(modelo, θ[1] == 0)
    # Condicion de estabilidad
    @constraint(modelo, [ii in 1:nL], - pi/3 <=  θ[dLinea.fbus[ii]] - θ[dLinea.tbus[ii]] <= pi/3)

    ########## RESOLUCIÓN ##########
    optimize!(modelo) # Optimización

    return Ls
end