function calculoOPF(modelo, dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nN::Int, nL::Int, bMVA::Int)
    ########## GESTIÓN DE DATOS ##########
    P_Cost0, P_Cost1, P_Cost2, P_Gen_lb, P_Gen_ub, Gen_Status, P_Demand = gestorDatosLP(dGen, dNodo, nN, bMVA)

    # Matriz de susceptancias de las líneas
    B = matrizSusceptancia(dLinea, nN, nL)
    
    ########## VARIABLES ##########
    # Se asigna una variable de generación para todos los nodos y se le asigna un valor inicial de 0 
    @variable(modelo, P_G[ii in 1:nN], start = 0)

    # Se considera que el módulo del voltaje en todos los nodos es la unidad y es invariante, V = 1
    # Lo único que varía es el ángulo
    @variable(modelo, θ[1:nN], start = 0)

    # El flujo por la línea que conecta los nodos i-j es igual de la susceptancia de la línea por la diferencia de ángulos entre los nodos i-j
    # Pᵢⱼ = Bᵢⱼ · (θᵢ - θⱼ)
    @variable(modelo, Pₗᵢₙₑ[ii in 1:nN, jj in 1:nN], start = 0)
    @constraint(modelo, [ii in 1:nN, jj in 1:nN], Pₗᵢₙₑ[i,j] == B[i, j] * (θ[j] - θ[i]))

    ########## FUNCIÓN OBJETIVO ##########
    # El objetivo del problema es reducir el coste total que se calcula como ∑cᵢ·Pᵢ
    # Siendo:
    #   cᵢ el coste del Generador en el nodo i
    #   Pᵢ la potencia generada del Generador en el nodo i
    Total_cost = sum((P_Cost0[ii] + P_Cost1[ii] * P_G[ii] * bMVA + P_Cost2[ii] * (P_G[ii] * bMVA)^2) for ii in 1:nN)
    @objective(modelo, Min, Total_cost)


    ########## RESTRICCIONES ##########
    # Restricción de la relación entre los nodos: PGen[i] - PDem[i] = ∑(B[i,j] · θ[j]))
    # Siendo 
    # PGen[i] la potencia generada en el nodo i
    # PDem[i] la potencia demandada en el nodo i
    # B[i,j] susceptancia de la linea que conecta los nodos i - j
    # θ[j] ángulo del nodo j
    # En la parte izquierda es el balance entre Potencia Generada y Potencia Demandada
    # en caso de ser positivo significa que es un nodo que suministra potencia a la red 
    # y en caso negativo, consume potencia de la red
    # Y en la parte derecha es la función del flujo de potencia en la red
    node_power_balance = []
    for ii in 1:nN
        local_node_power_balance = @constraint(modelo, P_G[ii]*bMVA == (sum(Pₗᵢₙₑ[ii,jj] for jj in 1:nN) + P_Demand[ii])*bMVA)
        push!(node_power_balance, local_node_power_balance)
    end

    # Restricción de potencia máxima por la línea
    # Siendo la potencia que circula en la linea que conecta los nodos i-j: Pᵢⱼ = Bᵢⱼ·(θᵢ-θⱼ) 
    # Su valor abosoluto debe ser menor que el dato de potencia max en dicha línea "dLinea.L_SMAX"
    @constraint(modelo, [ii in 1:nL], -dLinea.L_SMAX[ii] * dLinea.status[ii] / bMVA <= Pₗᵢₙₑ[dLinea.F_BUS[ii], dLinea.T_BUS[ii]] <= dLinea.L_SMAX[ii] * dLinea.status[ii] / bMVA)

    # Restricción de potencia mínima y máxima de los generadores
    @constraint(modelo, [ii in 1:nN], P_Gen_lb[ii] * Gen_Status[ii] <= P_G[ii] <= P_Gen_ub[ii] * Gen_Status[ii])

    # Se selecciona el nodo 1 como nodo de refenrecia
    # Necesario en caso de HiGHS para evitar un bucle infinito al resolver la optimización
    @constraint(modelo, θ[1] == 0)

    ########## RESOLUCIÓN ##########
    optimize!(modelo) # Optimización

    ########### DUAL LMP ###########
    LMPs = []
    if has_duals(modelo)
        for ii in 1:nN
            push!(LMPs, dual(node_power_balance[ii]))
        end
    end

    return modelo, P_G, Pₗᵢₙₑ, θ, LMPs
end