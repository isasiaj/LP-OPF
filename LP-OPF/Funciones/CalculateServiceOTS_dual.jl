function CalculateServiceOTS_dual(solver::String, dLinea::DataFrame, dLineaPre::DataFrame, dGen::DataFrame, dNodo::DataFrame, nL::Int, nG::Int,nN::Int, bMVA::Int, last_P_G, last_Pₗᵢₙₑ, last_θ)
    modelo = IncializarModelo(solver)
    set_optimizer_attribute(modelo, "tol", 1e-30)
    ########## GESTIÓN DE DATOS ##########
    P_Cost0, P_Cost1, P_Cost2, P_Gen_lb, P_Gen_ub, Gen_Status, P_Demand = gestorDatosLP(dGen, dNodo, nN, bMVA)

    # Array de susceptancias de las líneas
    B = matrizSusceptancia(dLinea)

    ########## VARIABLES ##########
    # Se asigna una variable de generación para todos los nodos y se le asigna un valor inicial de 0 
    @variable(modelo, P_G[ii in 1:nG], start = 0)

    for ii in 1:nG
        set_start_value(P_G[ii], last_P_G[ii])
    end

    # Se considera que el módulo del voltaje en todos los nodos es la unidad y es invariante, V = 1
    # Lo único que varía es el ángulo
    @variable(modelo, θ[ii in 1:nN], start = 0)

    for ii in 1:nN
        set_start_value(θ[ii], last_θ[ii])
    end

    # El flujo por la línea que conecta los nodos i-j es igual de la susceptancia de la línea por la diferencia de ángulos entre los nodos i-j
    # Pᵢⱼ = Bᵢⱼ · (θᵢ - θⱼ)
    @variable(modelo, Pₗᵢₙₑ[ii in 1:nL], start = 0)

    for ii in 1:nL
        set_start_value(Pₗᵢₙₑ[ii], last_Pₗᵢₙₑ[ii])
    end

    @variable(modelo, Ls[ii in 1:nL], start = 0)

    for ii in 1:nL
        set_start_value(Ls[ii], dLinea.status[ii])
    end

    ########## FUNCIÓN OBJETIVO ##########
    # El objetivo del problema es reducir el coste total que se calcula como ∑cᵢ·Pᵢ
    # Siendo:
    #   cᵢ el coste del Generador en el nodo i
    #   Pᵢ la potencia generada del Generador en el nodo i
    Total_cost = sum((P_Cost0[ii] + P_Cost1[ii] * P_G[ii] * bMVA + P_Cost2[ii] * (P_G[ii] * bMVA)^2) for ii in 1:nG) 
    @objective(modelo, Min, Total_cost)


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
    @constraint(modelo, [ii in 1:nN], (sum(P_G[jj] for jj in 1:nG if dGen.bus[jj] == ii ) - P_Demand[ii])*bMVA == (sum(Pₗᵢₙₑ[jj] for jj in 1:nL if dLinea.fbus[jj] == ii ) - sum(Pₗᵢₙₑ[jj] for jj in 1:nL if dLinea.tbus[jj] == ii ))*bMVA)

    # Se usa el resultado del OTS de la simulación anterior para obtener el estado de las lineas.
    # Se separa entre lineas conectadas y no conectada, para usar o no la variable Ls en los limites de potencia


    fixed_line_state = []
    fixed_line_state2 = []
    fixed_line_state3 = []

    for ii in 1:nL
        if  dLinea.status[ii] != dLineaPre.status[ii]
            if dLinea.status[ii] == 1
                @constraint(modelo, Ls[ii] >= dLineaPre.status[ii])
                @constraint(modelo, Ls[ii] <= dLineaPre.status[ii])
                # Restricción de potencia máxima por la línea, debe ser menor que el dato de potencia max en dicha línea "dLinea.rateA"
                local_line_state  = @constraint(modelo, Pₗᵢₙₑ[ii] >= -(dLinea.rateA[ii]/bMVA) * Ls[ii])
                local_line_state2  = @constraint(modelo, Pₗᵢₙₑ[ii] <=  (dLinea.rateA[ii]/bMVA) * Ls[ii])
                # Restriccion de la potencia que circula por las lineas segun las leyes de kirchhoff simplificadas, para el calculo de LP-OPF.
                # Siendo la potencia que circula en la linea que conecta los nodos i-j: Pᵢⱼ = Bᵢⱼ·(θᵢ-θⱼ)
                local_line_state3 = @constraint(modelo, Pₗᵢₙₑ[ii] == B[ii] * (θ[dLinea.fbus[ii]] - θ[dLinea.tbus[ii]]) * Ls[ii])
            else
                @constraint(modelo, Ls[ii] >= 1)
                @constraint(modelo, Ls[ii] <= 1)
                # Restricción de potencia máxima por la línea, debe ser menor que el dato de potencia max en dicha línea "dLinea.rateA"
                local_line_state3 = @constraint(modelo, Pₗᵢₙₑ[ii] >= -(dLinea.rateA[ii]/bMVA) * Ls[ii])
                local_line_state = @constraint(modelo, Pₗᵢₙₑ[ii] <=  (dLinea.rateA[ii]/bMVA) * Ls[ii])
                # Restriccion de la potencia que circula por las lineas segun las leyes de kirchhoff simplificadas, para el calculo de LP-OPF.
                # Siendo la potencia que circula en la linea que conecta los nodos i-j: Pᵢⱼ = Bᵢⱼ·(θᵢ-θⱼ)
                local_line_state2 = @constraint(modelo, Pₗᵢₙₑ[ii] == B[ii] * (θ[dLinea.fbus[ii]] - θ[dLinea.tbus[ii]]) * (Ls[ii]))
            end
            push!(fixed_line_state,local_line_state)
            push!(fixed_line_state2,local_line_state2)
            push!(fixed_line_state3,local_line_state3)
        else
            if dLinea.status[ii] == 1
                # Restricción de potencia máxima por la línea, debe ser menor que el dato de potencia max en dicha línea "dLinea.rateA"
                @constraint(modelo, Pₗᵢₙₑ[ii] >= -(dLinea.rateA[ii] / bMVA))
                @constraint(modelo, Pₗᵢₙₑ[ii] <=  (dLinea.rateA[ii] / bMVA))
                # Restriccion de la potencia que circula por las lineas segun las leyes de kirchhoff simplificadas, para el calculo de LP-OPF.
                # Siendo la potencia que circula en la linea que conecta los nodos i-j: Pᵢⱼ = Bᵢⱼ·(θᵢ-θⱼ)
                @constraint(modelo, Pₗᵢₙₑ[ii] == B[ii] * (θ[dLinea.fbus[ii]] - θ[dLinea.tbus[ii]]))
            else
                @constraint(modelo, Pₗᵢₙₑ[ii] == 0)
            end
                
            push!(fixed_line_state,0)
            push!(fixed_line_state2,0)
            push!(fixed_line_state3,0)
        end
    end

    # Restricción de potencia mínima y máxima de los generadores
    @constraint(modelo, [ii in 1:nG], P_Gen_lb[ii] * Gen_Status[ii] <= P_G[ii] <= P_Gen_ub[ii] * Gen_Status[ii])

    # Se selecciona el nodo 1 como nodo de refenrecia
    # Necesario en caso de HiGHS para evitar un bucle infinito al resolver la optimización
    @constraint(modelo, θ[1] == 0)
    # Condicion de estabilidad
    @constraint(modelo, [ii in 1:nL],- pi/3 <=  θ[dLinea.fbus[ii]] - θ[dLinea.tbus[ii]] <= pi/3)

    ########## RESOLUCIÓN ##########
    optimize!(modelo) # Optimización

    ########### DUAL LMP ###########
    # Se calcula el dual de cada nodo repecto ala restriccion del balance de potencia.
    # Dado que la funcion de coste es el euros el resultado quedaria en:  €/MWh

    OTSservice = []
    for ii in 1:nL
        if dLinea.status[ii] != dLineaPre.status[ii]
            if dLinea.status[ii] == 1
                push!(OTSservice, dual(fixed_line_state[ii]) + dual(fixed_line_state2[ii]) + dual(fixed_line_state3[ii]))
            else
                push!(OTSservice, 0)
            end
        else
            push!(OTSservice, 0)
        end
    end

    return OTSservice
end