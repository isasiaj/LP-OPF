function calculoOPF(modelo, dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nL::Int, nG::Int,nN::Int, bMVA::Int)
    ########## GESTIÓN DE DATOS ##########
    P_Cost0, P_Cost1, P_Cost2, P_Gen_lb, P_Gen_ub, Gen_Status, P_Demand = gestorDatosLP(dGen, dNodo, nN, bMVA)

    # Array de susceptancias de las líneas
    B = matrizSusceptancia(dLinea)
    
    ########## VARIABLES ##########
    # Se crean las variables de generadores con valor inicial de 0 
    @variable(modelo, P_G[ii in 1:nG], start = 0)

    # Al consider que el módulo del voltaje en todos los nodos es la unidad y es invariante, V = 1
    # Lo único que varía es el ángulo
    # Se crean las variables de los angulos para todos los nodos con valor inicial de 0 
    @variable(modelo, θ[1:nN], start = 0)

    # El flujo por la línea que conecta los nodos i-j es igual de la susceptancia de la línea por la diferencia de ángulos entre los nodos i-j
    # Pᵢⱼ = Bᵢⱼ · (θᵢ - θⱼ)
    # Se crean las variables de los flujos de potencia para todas las lineas con valor inicial de 0 
    @variable(modelo, Pₗᵢₙₑ[ii in 1:nL], start = 0)

    ########## FUNCIÓN OBJETIVO ##########
    # El objetivo del problema es reducir el coste total que se calcula como ∑cᵢ·Pᵢ
    # Siendo:
    #   cᵢ el coste del Generador en el nodo i
    #   Pᵢ la potencia generada del Generador en el nodo i
    Total_cost = sum((P_Cost0[ii] + P_Cost1[ii] * P_G[ii] * bMVA + P_Cost2[ii] * (P_G[ii] * bMVA)^2) for ii in 1:nG)
    @objective(modelo, Min, Total_cost)


    ########## RESTRICCIONES ##########
    # Restricción de la relación entre los nodos: PGen[i] - PDem[i] = ∑(Pₗᵢₙₑ salientes) - ∑(Pₗᵢₙₑ entrantes)
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

    for ii in 1:nL
        if dLinea.status[ii] == 1
            # Restricción de potencia máxima por la línea
            # Su valor abosoluto debe ser menor que el dato de potencia max en dicha línea "dLinea.rateA"
            @constraint(modelo, Pₗᵢₙₑ[ii] >= -(dLinea.rateA[ii] / bMVA))
            @constraint(modelo, Pₗᵢₙₑ[ii] <=  (dLinea.rateA[ii] / bMVA))
                
            # Restriccion de la potencia que circula por las lineas segun las leyes de kirchhoff simplificadas, para el calculo de LP-OPF.
            # B[ii] susceptancia de la linea ii, que conecta los nodos fbus[ii] - tbus[ii]
            # θ[ii] ángulo del nodo ii
            # Siendo la potencia que circula en la linea que conecta los nodos i-j: Pᵢⱼ = Bᵢⱼ·(θᵢ-θⱼ)
            @constraint(modelo, Pₗᵢₙₑ[ii] == B[ii] * (θ[dLinea.fbus[ii]] - θ[dLinea.tbus[ii]]))
        else
            @constraint(modelo, Pₗᵢₙₑ[ii] ==  0)
        end
    end


    # Restricciones de potencia mínima y máxima de los generadores (esta linea equivale a dos restricciones)
    @constraint(modelo, [ii in 1:nG], P_Gen_lb[ii] * Gen_Status[ii] <= P_G[ii] <= P_Gen_ub[ii] * Gen_Status[ii])

    # Se selecciona el nodo 1 como nodo de refenrecia
    # Necesario en caso de HiGHS para evitar un bucle infinito al resolver la optimización
    @constraint(modelo, θ[1] == 0)
    # Condicion de estabilidad
    @constraint(modelo, [ii in 1:nL], - pi/3 <=  θ[dLinea.fbus[ii]] - θ[dLinea.tbus[ii]] <= pi/3)

    ########## RESOLUCIÓN ##########
    optimize!(modelo) # Optimización

    ########### DUAL LMP ###########
    # Se calcula el dual de cada nodo repecto ala restriccion del balance de potencia.
    # Dado que la funcion de coste es el euros el resultado quedaria en:  €/MWh
    LMPs = []
    for ii in 1:nN
        push!(LMPs, dual(node_power_balance[ii]))
    end

    return modelo, [round(value(P_G[ii]), digits = 6) for ii in 1:nG], [round(value(Pₗᵢₙₑ[ii]), digits = 6) for ii in 1:nL], [round(value(θ[ii]), digits = 6) for ii in 1:nN], LMPs
end