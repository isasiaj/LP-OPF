# PENDIENTE:
# Latex (esquema) - Overleaf

# Explicar en caso de considerar pérdidas

include("./Funciones/gestorDatosLP.jl")
include("./Funciones/matrizSusceptancia.jl")
include("./Funciones/calculoOPF.jl")

function LP_OPF(dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nL::Int, nG::Int, nN::Int, bMVA::Int, solver::String, Calculate_LMP::Bool, Calculate_LineSW::Bool) 

    # dLinea:   Datos de las líneas
    # dGen:     Datos de los generadores
    # dNodo:    Datos de la demanda
    # nN:       Número de nodos
    # nL:       Número de líneas
    # bMVA:     Potencia base
    # solver:   Solver a utilizar
    

    ########## INICIALIZAR MODELO ##########
    # Se crea el modelo "m_cons" con la función de JuMP.Model() y tiene como argumento el optimizador usado,
    # y el modelo "m_no_cons" con la función.
    # El modelo "m_no_cons" no se tendra en cuenta la potencia maxima en las lineas, para hacer el calculo 
    # del precio marginal sin el coste por congestion en las lineas

    if solver == "Gurobi"   # en este caso, el solver Gurobi
        m_cons = Model(Gurobi.Optimizer)
        m_no_cons = Model(Gurobi.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m_cons)
        set_silent(m_no_cons)

    elseif solver == "HiGHS"    # Para el solver HiGHS
        m_cons = Model(HiGHS.Optimizer)
        m_no_cons = Model(HiGHS.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m_cons)
        set_silent(m_no_cons)

    elseif solver == "Ipopt"    # Para el solver Ipopt
        m_cons = Model(Ipopt.Optimizer)        
        m_no_cons = Model(Ipopt.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m_cons)
        set_silent(m_no_cons)
    
    else # En caso de error
        println("ERROR: Selección de solver en DC-OPF")
    
    end

    # Optimizacion con modelo de restriccion por potecnia maxima en las lineas.
    m_cons, P_G, Pₗᵢₙₑ, θ, Z, node_lmp =calculoOPF(m_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA, Calculate_LMP, Calculate_LineSW)

    
    if Calculate_LMP
        # Se crea unos nuevos datos de lineas de manera que la potencia maxima es ifgual a la demanda total 
        # del sistema.
        dLinea_no_cons= copy(dLinea)
        for ii in 1:nL
            dLinea_no_cons.L_SMAX[ii] =  round(Int, sum(dNodo.PD))
        end
        # Se elimina la restriccion de potencia maxima en las lineas para calculas los costes por congestion
        m_no_cons, _, _, _, _, node_mec =calculoOPF(m_no_cons, dLinea_no_cons, dGen, dNodo, nL, nG, nN, bMVA, Calculate_LMP, Calculate_LineSW)
    end
    
    # Guardar solución en DataFrames en caso de encontrar solución óptima en cada modelo.
    if ((termination_status(m_cons) == OPTIMAL || termination_status(m_cons) == LOCALLY_SOLVED || termination_status(m_cons) == ITERATION_LIMIT))
        # solGen recoge los valores de la potencia generada de cada generador de la red
        # Primera columna: nodo
        # Segunda columna: valor lo toma de la variable "P_G" (está en pu y se pasa a MVA) del generador de dicho nodo.
        solGen = DataFrames.DataFrame(BUS = (dGen.BUS), PGEN = (value.(P_G) * bMVA))

        # solFlujos recoge el flujo de potencia que pasa por todas las líneas
        # Primera columna: nodo del que sale
        # Segunda columna: nodo al que llega
        # Tercera columna: valor del flujo de potencia en la línea
        # Cuarta  columna: valor en tanto por uno de la satuaracion de la linea:  potencia en la línea / potencia maxima en la linea
        solFlujos = DataFrames.DataFrame(F_BUS = Int[], T_BUS = Int[], FLUJO = Float64[], LINE_CAPACITY = Float64[], SWITCH = Float64[])

        for ii in 1:nL
            # Se crean dos casos para que siempre la potencia de positiva, invirtiendo nodos F_BUS y T_BUS
            if value(Pₗᵢₙₑ[ii] ) >= 0
                push!(solFlujos, Dict(:F_BUS => (dLinea.F_BUS[ii]),
                                      :T_BUS => (dLinea.T_BUS[ii]), 
                                      :FLUJO => round(value(Pₗᵢₙₑ[ii]) * bMVA, digits = 2), 
                                      :LINE_CAPACITY => round((value(Pₗᵢₙₑ[ii]) * bMVA)/dLinea.L_SMAX[ii], digits = 3),
                                      :SWITCH => value(Z[ii])))

            else
                push!(solFlujos, Dict(:F_BUS => (dLinea.T_BUS[ii]), 
                                      :T_BUS => (dLinea.F_BUS[ii]), 
                                      :FLUJO => round(-value(Pₗᵢₙₑ[ii]) * bMVA, digits = 2), 
                                      :LINE_CAPACITY => round((-value(Pₗᵢₙₑ[ii]) * bMVA)/dLinea.L_SMAX[ii], digits = 3),
                                      :SWITCH => value(Z[ii])))
            end
        end

        # solAngulos recoge el desfase de la tensión en los nodos
        # Primera columna: nodo
        # Segunda columna: valor del desfase en grados
        solAngulos = DataFrames.DataFrame(BUS = Int[], GRADOS = Float64[])
        for ii in 1:nN
            push!(solAngulos, Dict(:BUS => ii, :GRADOS => round(rad2deg(value(θ[ii])), digits = 2)))
        end

        # solLMP recoge los precios marginales en cada nodo
        # Primera columna: nodo
        # Segunda columna: Precio marginal local en cada de la red
        # Tercera columna: Componente de energia, este es igual en todos los nodos al no tener en cuenta saturacion en las lineas
        # Cuarta  columna: componente de congestion del precio marginal, como afecta la congestion en las lineas sobre el precio marginal en ese nodo.
        solLMP = DataFrames.DataFrame(BUS = Int[], LMP = Float64[], MEC = Float64[], MCC = Float64[])
        if Calculate_LMP
            for ii in 1:nN
                # Marginal price of energy, €/MWh
                push!(solLMP, Dict(:BUS => ii, 
                                :LMP => round(node_lmp[ii], digits = 3),
                                :MEC => round(node_mec[ii], digits = 3),
                                :MCC => round(node_lmp[ii] - node_mec[ii], digits = 3)))
            end
        end

        # Devuelve como solución el modelo "m_cons" y los DataFrames generados de generación, flujos y ángulos
        # se deuvlve m_cons ya que tiene en cuenta las restricciones reales de las lineas.
        return m_cons, solGen, solFlujos, solAngulos, solLMP

    # En caso de que no se encuentre solución a la optimización, se mostrará en pantalla el error
    else
        println("ERROR: ", termination_status(m_cons))
    end

end