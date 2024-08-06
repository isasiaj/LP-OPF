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
        m_cons = Model(Gurobi.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m_cons)

        m_no_cons = Model(Gurobi.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m_no_cons)

    # Para el solver HiGHS
    elseif solver == "HiGHS"
        m_cons = Model(HiGHS.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m_cons)

        m_no_cons = Model(HiGHS.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m_no_cons)

    # Para el solver Ipopt
    elseif solver == "Ipopt"
        m_cons = Model(Ipopt.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m_cons)

        m_no_cons = Model(Ipopt.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m_no_cons)
    
    else # En caso de error
        println("ERROR: Selección de solver en DC-OPF")
    
    end

    # Optimizacion con modelo de restriccion en las lineas
    m_cons, P_G, Pₗᵢₙₑ, θ, node_lmp =calculoOPF(m_cons, dLinea, dGen, dNodo, nN, nL, bMVA)

    dLinea_no_cons= copy(dLinea)
    for ii in 1:nL
        dLinea_no_cons.L_SMAX[ii] =  round(Int, sum(dNodo.PD))
    end
    # Se elimina la restriccion de potencia maxima en las lineas para calculas los costes por saturación
    m_no_cons, _, _, _, node_mec =calculoOPF(m_no_cons, dLinea_no_cons, dGen, dNodo, nN, nL, bMVA)

    # Guardar solución en DataFrames en caso de encontrar solución óptima
    if ((termination_status(m_cons) == OPTIMAL || termination_status(m_cons) == LOCALLY_SOLVED || termination_status(m_cons) == ITERATION_LIMIT) &&
        (termination_status(m_no_cons) == OPTIMAL || termination_status(m_no_cons) == LOCALLY_SOLVED || termination_status(m_no_cons) == ITERATION_LIMIT))

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

        for ii in 1:nL
            if value(Pₗᵢₙₑ[dLinea.F_BUS[ii], dLinea.T_BUS[ii]] ) > 0
                push!(solFlujos, Dict(:F_BUS => (dLinea.F_BUS[ii]),
                                      :T_BUS => (dLinea.T_BUS[ii]), 
                                      :FLUJO => round(value(Pₗᵢₙₑ[dLinea.F_BUS[ii], dLinea.T_BUS[ii]]) * bMVA, digits = 2), 
                                      :LINE_CAPACITY => round((value(Pₗᵢₙₑ[dLinea.F_BUS[ii], dLinea.T_BUS[ii]]) * bMVA)/dLinea.L_SMAX[ii], digits = 3)))

            elseif value(Pₗᵢₙₑ[dLinea.F_BUS[ii], dLinea.T_BUS[ii]]) != 0
                push!(solFlujos, Dict(:F_BUS => (dLinea.T_BUS[ii]), 
                                      :T_BUS => (dLinea.F_BUS[ii]), 
                                      :FLUJO => round(-value(Pₗᵢₙₑ[dLinea.F_BUS[ii], dLinea.T_BUS[ii]]) * bMVA, digits = 2), 
                                      :LINE_CAPACITY => round((-value(Pₗᵢₙₑ[dLinea.F_BUS[ii], dLinea.T_BUS[ii]]) * bMVA)/dLinea.L_SMAX[ii], digits = 3)))
            end
        end

        # solAngulos recoge el desfase de la tensión en los nodos
        # Primera columna: nodo
        # Segunda columna: valor del desfase en grados
        solAngulos = DataFrames.DataFrame(BUS = Int[], GRADOS = Float64[])
        for ii in 1:nN
            push!(solAngulos, Dict(:BUS => ii, :GRADOS => round(rad2deg(value(θ[ii])), digits = 2)))
        end

        solLMP = DataFrames.DataFrame(BUS = Int[], LMP = Float64[], MEC = Float64[], MCC = Float64[])
        for ii in 1:nN
            # Marginal price of energy, €/MWh
            push!(solLMP, Dict(:BUS => ii, 
                               :LMP => round(node_lmp[ii], digits = 3),
                               :MEC => round(node_mec[ii], digits = 3),
                               :MCC => round(node_lmp[ii] - node_mec[ii], digits = 3)))
        end

        # Devuelve como solución el modelo "m" y los DataFrames generados de generación, flujos y ángulos
        return m_cons, solGen, solFlujos, solAngulos, solLMP

    # En caso de que no se encuentre solución a la optimización, se mostrará en pantalla el error
    else
        println("ERROR: ", termination_status(m_cons))
    end

end