# En esta funcion se calcula el punto optimo de la red recibida por parámetros, y sus precios marginales locales.
# Esta funcion se usa como modelo base el todos los tipos de estudio seleccionables
#
# Entrada
#   solver:     String que contiene el nombre del modelo a utilizar
#   dLinea:     Datos de las líneas
#   dGen:       Datos de los generadores
#   dNodo:      Datos de la demanda
#   nL:         Número de líneas
#   nG:         Número de generadores
#   nN:         Número de nodos
#   bMVA:       Potencia base
#   solver:     Solver a utilizar
# Salida
#   Codigo_Fin: Estado en el que termino la optimizacion
#   coste:      Coste optimo total del sistema
#   P_G:        Lista solución optima, generadores
#   Pₗᵢₙₑ:       Lista solución optima, lineas
#   θ:          Lista solución optima, angulo de los nodos
#   LMPs:       Lista solución optima, precios marginales locales

function calculoOPF(solver::String, dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nL::Int, nG::Int,nN::Int, bMVA::Int)
    # Crear objeto modelo de optimizacion
    modelo = IncializarModelo(solver)
    ########## GESTIÓN DE DATOS ##########
    P_Cost0, P_Cost1, P_Cost2, P_Gen_lb, P_Gen_ub, Gen_Status, P_Demand = gestorDatosLP(dGen, dNodo, nN, bMVA)

    # Array de susceptancias de las líneas
    B = matrizSusceptancia(dLinea)
    
    ########## VARIABLES ##########
    # Varibles de la potencia por unidad aportada por cada generdor
    @variable(modelo, P_G[ii in 1:nG], start = 0)

    # Consideramos que el módulo del voltaje en todos los nodos es la unidad, V = 1
    # Lo único que varía es el ángulo
    # Variables de los angulos en radianes de los nodos
    @variable(modelo, θ[1:nN], start = 0)

    # Flujo de potencia linelizado por la línea ii
    # Variables de los flujos de potencia por unidad para todas las lineas
    @variable(modelo, Pₗᵢₙₑ[ii in 1:nL], start = 0)

    ########## FUNCIÓN OBJETIVO ##########
    # El objetivo del problema es reducir el coste total que se calcula como ∑cᵢ·Pᵢ
    # Siendo:
    #   cᵢ el coste del Generador en el nodo i
    #   Pᵢ la potencia generada del Generador en el nodo i
    Total_cost = sum(((P_Cost0[ii] + P_Cost1[ii] * P_G[ii] * bMVA + P_Cost2[ii] * (P_G[ii] * bMVA)^2)*Gen_Status[ii]) for ii in 1:nG)
    @objective(modelo, Min, Total_cost)


    ########## RESTRICCIONES ##########
    # Restricción de la relación entre los nodos: PGen[i] - PDem[i] = ∑(Pₗᵢₙₑ salientes) - ∑(Pₗᵢₙₑ entrantes)
    # Siendo:

    # En la parte izquierda es el balance entre Potencia Generada menos Potencia Demandada
    #   P_G[ii] la potencia generada en el nodo ii
    #   P_Demand[ii] la potencia demandada en el nodo ii
    # Positivo, el nodo que suministra potencia a la red y negativo, consume potencia de la red.
    # Y en la parte derecha es la función del flujo hacia la red
    # Se multiplica a ambos lados por bMVA para asegurar que a la hora de calcular el dual quede con unidades €/MW
    node_power_balance = []
    for ii in 1:nN
        local_node_power_balance = @constraint(modelo, (sum(P_G[jj] for jj in 1:nG if dGen.bus[jj] == ii ) - P_Demand[ii])*bMVA == (sum(Pₗᵢₙₑ[jj] for jj in 1:nL if dLinea.fbus[jj] == ii ) - sum(Pₗᵢₙₑ[jj] for jj in 1:nL if dLinea.tbus[jj] == ii ))*bMVA)
        push!(node_power_balance, local_node_power_balance)
    end

    for ii in 1:nL
        if dLinea.status[ii] == 1
            # Restricciones de potencias máxima y mínima por la línea ii
            # Su valor abosoluto debe ser menor que el dato de potencia max en dicha línea "dLinea.rateA"
            @constraint(modelo, Pₗᵢₙₑ[ii] >= -(dLinea.rateA[ii] / bMVA))
            @constraint(modelo, Pₗᵢₙₑ[ii] <=  (dLinea.rateA[ii] / bMVA))
                
            # Restriccion de la potencia que circula por las lineas segun las leyes de kirchhoff simplificadas.
            # B[ii] susceptancia de la linea ii, que conecta los nodos fbus[ii] - tbus[ii]
            # θ[ii] ángulo del nodo ii
            #   fbus[ii]: nodo definido como origen de la linea
            #   fbus[ii]: nodo definido como destino de la linea
            # Siendo la potencia que circula en la linea que conecta los nodos i-j: Pᵢ = Bᵢ·(θᵢ₁-θᵢ₁)
            @constraint(modelo, Pₗᵢₙₑ[ii] == B[ii] * (θ[dLinea.fbus[ii]] - θ[dLinea.tbus[ii]]))
        else
            # Si el estado de la linea es cero, por esta no puede circular potencia
            @constraint(modelo, Pₗᵢₙₑ[ii] ==  0)
        end
    end


    # Restricciones de potencia mínima y máxima de los generadores (esta linea equivale a dos restricciones)
    #   Si P_Gen_lb > 0 ud de potencia, el generador siempre estrá encendido
    @constraint(modelo, [ii in 1:nG], P_Gen_lb[ii] * Gen_Status[ii] <= P_G[ii] <= P_Gen_ub[ii] * Gen_Status[ii])

    # Se selecciona el nodo 1 como nodo de refencia de tensión, por lo que tiene angulo igual a 0 rad
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
    Codigo_Fin = termination_status(modelo)
    coste = objective_value(modelo)

    return Codigo_Fin, coste, [value(P_G[ii]) for ii in 1:nG], [value(Pₗᵢₙₑ[ii]) for ii in 1:nL], [value(θ[ii]) for ii in 1:nN], LMPs
end