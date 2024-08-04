# PENDIENTE:
# Latex (esquema) - Overleaf

# Explicar en caso de considerar pérdidas

include("./Funciones/gestorDatosLP.jl")
include("./Funciones/matrizSusceptancia.jl")
include("./Funciones/calculoOPF.jl")

function LP_OPF(dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nN::Int, nL::Int, bMVA::Int, solver::String) 

    # dLinea:   Datos de las líneas
    # dGen:     Datos de los generadores
    # dNodo:    Datos de la demanda
    # nN:       Número de nodos
    # nL:       Número de líneas
    # bMVA:     Potencia base
    # solver:   Solver a utilizar
    

    ########## INICIALIZAR MODELO ##########
    # Se crea el modelo "m" con la función de JuMP.Model() y tiene como argumento el optimizador usado,
    # en este caso, el solver Gurobi
    if solver == "Gurobi"
        # Nota Mayo de 2024: se probó modelar la variable binaria on/off de los generadores y funcionaba con Gurobi
        m = Model(Gurobi.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m)

    # Para el solver HiGHS
    elseif solver == "HiGHS"
        m = Model(HiGHS.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m)

    # Para el solver Ipopt
    elseif solver == "Ipopt"
        m = Model(Ipopt.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m)
    
    # En caso de error
    else
        println("ERROR: Selección de solver en DC-OPF")
    
    end

    ########## GESTIÓN DE DATOS ##########
    P_Cost0, P_Cost1, P_Cost2, P_Gen_lb, P_Gen_ub, Gen_Status, P_Demand = gestorDatosLP(dGen, dNodo, nN, bMVA)

    # Matriz de susceptancias de las líneas
    B = matrizSusceptancia(dLinea, nN, nL)

    ########## VARIABLES ##########
    # Se asigna una variable de generación para todos los nodos y se le asigna un valor inicial de 0 
    @variable(m, P_G[i in 1:nN], start = 0)

    # Se considera que el módulo del voltaje en todos los nodos es la unidad y es invariante, V = 1
    # Lo único que varía es el ángulo
    @variable(m, θ[1:nN], start = 0)

    # Flujo de potecia en cad linea
    @variable(m, Pₗᵢₙₑ[i in 1:nN, j in 1:nN], start = 0)
    @constraint(m, [i in 1:nN, j in 1:nN], Pₗᵢₙₑ[i,j] == B[i, j] * (θ[j] - θ[i]))

    ########## FUNCIÓN OBJETIVO ##########
    # El objetivo del problema es reducir el coste total que se calcula como ∑cᵢ·Pᵢ
    # Siendo:
    #   cᵢ el coste del Generador en el nodo i
    #   Pᵢ la potencia generada del Generador en el nodo i
    Total_cost = sum((P_Cost0[i] + P_Cost1[i] * P_G[i] * bMVA + P_Cost2[i] * (P_G[i] * bMVA)^2) for i in 1:nN)
    @objective(m, Min, Total_cost)


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
    for i in 1:nN
        local_node_power_balance = @constraint(m, P_G[i]*bMVA == (sum(Pₗᵢₙₑ[i,j] for j in 1:nN) + P_Demand[i])*bMVA)
        push!(node_power_balance, local_node_power_balance)
    end

    # Restricción de potencia máxima por la línea
    # Siendo la potencia que circula en la linea que conecta los nodos i-j: Pᵢⱼ = Bᵢⱼ·(θᵢ-θⱼ) 
    # Su valor abosoluto debe ser menor que el dato de potencia max en dicha línea "dLinea.L_SMAX"
    @constraint(m, [i in 1:nL], -dLinea.L_SMAX[i] * dLinea.status[i] / bMVA <= Pₗᵢₙₑ[dLinea.F_BUS[i], dLinea.T_BUS[i]] <= dLinea.L_SMAX[i] * dLinea.status[i] / bMVA)

    # Restricción de potencia mínima y máxima de los generadores
    @constraint(m, [i in 1:nN], P_Gen_lb[i] * Gen_Status[i] <= P_G[i] <= P_Gen_ub[i] * Gen_Status[i])

    # Se selecciona el nodo 1 como nodo de refenrecia
    # Necesario en caso de HiGHS para evitar un bucle infinito al resolver la optimización
    @constraint(m, θ[1] == 0)

    ########## RESOLUCIÓN ##########
    optimize!(m) # Optimización

    # Guardar solución en DataFrames en caso de encontrar solución óptima
    if termination_status(m) == OPTIMAL || termination_status(m) == LOCALLY_SOLVED || termination_status(m) == ITERATION_LIMIT

        # for ii in 1:nN
        #     if value(node_power_balance[ii]) != 0
        #         println(value(node_power_balance[ii]))
        #     end
        # end

        # solGen recoge los valores de la potencia generada de cada generador de la red
        # Primera columna: nodo
        # Segunda columna: valor lo toma de la variable "P_G" (está en pu y se pasa a MVA) del generador de dicho nodo
        solGen = DataFrames.DataFrame(BUS = (dGen.BUS), PGEN = (value.(P_G[dGen.BUS]) * bMVA))

        # solFlujos recoge el flujo de potencia que pasa por todas las líneas
        # Primera columna: nodo del que sale
        # Segunda columna: nodo al que llega
        # Tercera columna: valor del flujo de potencia en la línea
        solFlujos = DataFrames.DataFrame(F_BUS = Int[], T_BUS = Int[], FLUJO = Float64[], LINE_CAPACITY = Float64[])
        # El flujo por la línea que conecta los nodos i-j es igual de la susceptancia de la línea por la diferencia de ángulos entre los nodos i-j
        # Pᵢⱼ = Bᵢⱼ · (θᵢ - θⱼ)
        for i in 1:nL
            if value(Pₗᵢₙₑ[dLinea.F_BUS[i], dLinea.T_BUS[i]] ) > 0
                push!(solFlujos, Dict(:F_BUS => (dLinea.F_BUS[i]), :T_BUS => (dLinea.T_BUS[i]), :FLUJO => round(value(Pₗᵢₙₑ[dLinea.F_BUS[i], dLinea.T_BUS[i]]) * bMVA, digits = 2), :LINE_CAPACITY => round((value(Pₗᵢₙₑ[dLinea.F_BUS[i], dLinea.T_BUS[i]]) * bMVA)/dLinea.L_SMAX[i], digits = 3)))
            elseif value(Pₗᵢₙₑ[dLinea.F_BUS[i], dLinea.T_BUS[i]]) != 0
                push!(solFlujos, Dict(:F_BUS => (dLinea.T_BUS[i]), :T_BUS => (dLinea.F_BUS[i]), :FLUJO => round(-value(Pₗᵢₙₑ[dLinea.F_BUS[i], dLinea.T_BUS[i]]) * bMVA, digits = 2), :LINE_CAPACITY => round((-value(Pₗᵢₙₑ[dLinea.F_BUS[i], dLinea.T_BUS[i]]) * bMVA)/dLinea.L_SMAX[i], digits = 3)))
            end
        end

        # solAngulos recoge el desfase de la tensión en los nodos
        # Primera columna: nodo
        # Segunda columna: valor del desfase en grados
        solAngulos = DataFrames.DataFrame(BUS = Int[], GRADOS = Float64[])
        for i in 1:nN
            push!(solAngulos, Dict(:BUS => i, :GRADOS => round(rad2deg(value(θ[i])), digits = 2)))
        end

        solLMP = DataFrames.DataFrame(BUS = Int[], LMP = Float64[])
        for i in 1:nN
            # Marginal price of energy, €/MWh
            push!(solLMP, Dict(:BUS => i, :LMP => round(dual(node_power_balance[i]), digits = 3)))
        end

        # Devuelve como solución el modelo "m" y los DataFrames generados de generación, flujos y ángulos
        return m, solGen, solFlujos, solAngulos, solLMP

    # En caso de que no se encuentre solución a la optimización, se mostrará en pantalla el error
    else
        println("ERROR: ", termination_status(m))
    end

end