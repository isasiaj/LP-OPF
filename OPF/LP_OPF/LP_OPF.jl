# PENDIENTE:
# Latex (esquema) - Overleaf

# Explicar en caso de considerar pérdidas

include("./Funciones/gestorDatosLP.jl")
include("./Funciones/matrizSusceptancia.jl")
include("./Funciones/calculoOPF.jl")
include("./Funciones/calculoOPF_OTS_BinVar.jl")
include("./Funciones/calculoOPF_OTS_FloatVar.jl")
include("./Funciones/IncializarModelo.jl")

function LP_OPF(dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nL::Int, nG::Int, nN::Int, bMVA::Int, solver::String, Calculate_LineSW::String) 

    # dLinea:           Datos de las líneas
    # dGen:             Datos de los generadores
    # dNodo:            Datos de la demanda
    # nL:               Número de líneas
    # nG:               Número de generadores
    # nN:               Número de nodos
    # bMVA:             Potencia base
    # solver:           Solver a utilizar
    # Calculate_LineSW: Varible binaria, el usuario quiere optimizar modifcando la topologia de la red
    

    ########## INICIALIZAR MODELO ##########
    # Se crea el modelo "m_cons" con la función de JuMP.Model() y tiene como argumento el optimizador usado,
    # y el modelo "m_no_cons" con la función.
    # El modelo "m_no_cons" no se tendra en cuenta la potencia maxima en las lineas, para hacer el calculo 
    # del precio marginal sin el coste por congestion en las lineas
    m_cons    = IncializarModelo(solver)
    m_no_cons = IncializarModelo(solver)

    if Calculate_LineSW == "No OTS"
        # Optimizacion con modelo de restriccion por potencia maxima en las lineas.
        m_cons, P_G, Pₗᵢₙₑ, θ, node_lmp = calculoOPF(m_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA)

        # Se crea unos nuevos datos de lineas de manera que la potencia maxima es igual a la demanda total 
        # del sistema.
        dLinea_no_cons= copy(dLinea)
        for ii in 1:nL
            dLinea_no_cons.rateA[ii] =  round(Int, sum(dNodo.Pd))
        end
        # Se elimina la restriccion de potencia maxima en las lineas para calculas los costes por congestion
        m_no_cons, _, _, _, node_mec =calculoOPF(m_no_cons, dLinea_no_cons, dGen, dNodo, nL, nG, nN, bMVA)

        # Se copia varible para que la estructura de salida sea la misma en todos los casos
        dLinea_final= copy(dLinea)
    elseif Calculate_LineSW == "OTS no LMP"
        # se calcula una primera optimizacion con varible binarias para el esatdo de las lineas.
        m_cons, P_G, Pₗᵢₙₑ, θ, Z = calculoOPF_BinVar(m_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA)

        dLinea_final = copy(dLinea)
        
        for ii in 1:nL
            dLinea_final.status[ii] = value(Z[ii])
        end

        dLinea_no_cons= copy(dLinea_final)
        for ii in 1:nL
            dLinea_no_cons.rateA[ii] = round(Int, sum(dNodo.Pd))
        end
        node_lmp = zeros(nN)
        node_mec = zeros(nN)

    elseif Calculate_LineSW == "OTS M1"
        # se calcula una primera optimizacion con varible binarias para el esatdo de las lineas.
        _, _, _, _, Z = calculoOPF_BinVar(m_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA)

        dLinea_final = copy(dLinea)
        
        for ii in 1:nL
            dLinea_final.status[ii] = value(Z[ii])
        end
        # Se resetea el modelo para evitar errores
        m_cons = nothing
        m_cons = IncializarModelo(solver)

        # Optimizacion con modelo de restriccion por potencia maxima en las lineas.
        m_cons, P_G, Pₗᵢₙₑ, θ, node_lmp = calculoOPF(m_cons, dLinea_final, dGen, dNodo, nL, nG, nN, bMVA)

        # Se crea unos nuevos datos de lineas de manera que la potencia maxima es igual a la demanda total 
        # del sistema.
        dLinea_no_cons = copy(dLinea_final)
        for ii in 1:nL
            dLinea_no_cons.rateA[ii] = round(Int, sum(dNodo.Pd))
        end
        # Se elimina la restriccion de potencia maxima en las lineas para calculas los costes por congestion
        m_no_cons, _, _, _, node_mec = calculoOPF(m_no_cons, dLinea_no_cons, dGen, dNodo, nL, nG, nN, bMVA)
    elseif Calculate_LineSW == "OTS M2"
        # se calcula una primera optimizacion con varible binarias para el esatdo de las lineas.
        _, _, _, _, Z = calculoOPF_FloatVar(m_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA)

        dLinea_final = copy(dLinea)
        
        for ii in 1:nL
            dLinea_final.status[ii] = value(Z[ii])
        end
        # Se resetea el modelo para evitar errores
        m_cons = nothing
        m_cons = IncializarModelo(solver)

        # Optimizacion con modelo de restriccion por potencia maxima en las lineas.
        m_cons, P_G, Pₗᵢₙₑ, θ, node_lmp = calculoOPF(m_cons, dLinea_final, dGen, dNodo, nL, nG, nN, bMVA)

        # Se crea unos nuevos datos de lineas de manera que la potencia maxima es igual a la demanda total 
        # del sistema.
        dLinea_no_cons = copy(dLinea_final)
        for ii in 1:nL
            dLinea_no_cons.rateA[ii] = round(Int, sum(dNodo.Pd))
        end
        # Se elimina la restriccion de potencia maxima en las lineas para calculas los costes por congestion
        m_no_cons, _, _, _, node_mec = calculoOPF(m_no_cons, dLinea_no_cons, dGen, dNodo, nL, nG, nN, bMVA)
    end
    
    # Guardar solución en DataFrames en caso de encontrar solución óptima en cada modelo.
    if ((termination_status(m_cons) == OPTIMAL || termination_status(m_cons) == LOCALLY_SOLVED || termination_status(m_cons) == ITERATION_LIMIT))
        # solGen recoge los valores de la potencia generada de cada generador de la red
        # Primera columna: nodo
        # Segunda columna: valor lo toma de la variable "P_G" (está en pu y se pasa a MVA) del generador de dicho nodo.
        solGen = DataFrames.DataFrame(bus = (dGen.bus), PGEN = (value.(P_G) * bMVA))

        # solFlujos recoge el flujo de potencia que pasa por todas las líneas
        # Primera columna: nodo del que sale
        # Segunda columna: nodo al que llega
        # Tercera columna: valor del flujo de potencia en la línea
        # Cuarta  columna: valor en tanto por uno de la satuaracion de la linea:  potencia en la línea / potencia maxima en la linea
        solFlujos = DataFrames.DataFrame(fbus = Int[], tbus = Int[], FLUJO = Float64[], LINE_CAPACITY = Float64[], State0 = Float64[], State1 = Float64[])

        for ii in 1:nL
            # Se crean dos casos para que siempre la potencia de positiva, invirtiendo nodos fbus y tbus
            if value(Pₗᵢₙₑ[ii] ) >= 0
                push!(solFlujos, Dict(:fbus => (dLinea_final.fbus[ii]),
                                      :tbus => (dLinea_final.tbus[ii]), 
                                      :FLUJO => round(value(Pₗᵢₙₑ[ii]) * bMVA, digits = 2), 
                                      :LINE_CAPACITY => round((value(Pₗᵢₙₑ[ii]) * bMVA)/dLinea_final.rateA[ii], digits = 3),
                                      :State0 => value(dLinea.status[ii]),
                                      :State1 => value(dLinea_final.status[ii])))

            else
                push!(solFlujos, Dict(:fbus => (dLinea_final.tbus[ii]), 
                                      :tbus => (dLinea_final.fbus[ii]), 
                                      :FLUJO => round(-value(Pₗᵢₙₑ[ii]) * bMVA, digits = 2), 
                                      :LINE_CAPACITY => round((-value(Pₗᵢₙₑ[ii]) * bMVA)/dLinea_final.rateA[ii], digits = 3),
                                      :State0 => value(dLinea.status[ii]),
                                      :State1 => value(dLinea_final.status[ii])))
            end
        end

        # solAngulos recoge el desfase de la tensión en los nodos
        # Primera columna: nodo
        # Segunda columna: valor del desfase en grados
        solAngulos = DataFrames.DataFrame(bus_i = Int[], GRADOS = Float64[])
        for ii in 1:nN
            push!(solAngulos, Dict(:bus_i => ii, :GRADOS => round(rad2deg(value(θ[ii])), digits = 2)))
        end

        # solLMP recoge los precios marginales en cada nodo
        # Primera columna: nodo
        # Segunda columna: Precio marginal local en cada de la red
        # Tercera columna: Componente de energia, este es igual en todos los nodos al no tener en cuenta saturacion en las lineas
        # Cuarta  columna: componente de congestion del precio marginal, como afecta la congestion en las lineas sobre el precio marginal en ese nodo.
        solLMP = DataFrames.DataFrame(bus_i = Int[], LMP = Float64[], MEC = Float64[], MCC = Float64[])
        for ii in 1:nN
            # Marginal price of energy, €/MWh
            push!(solLMP, Dict(:bus_i => ii, 
                            :LMP => round(node_lmp[ii], digits = 3),
                            :MEC => round(node_mec[ii], digits = 3),
                            :MCC => round(node_lmp[ii] - node_mec[ii], digits = 3)))
        end

        # Devuelve como solución el modelo "m_cons" y los DataFrames generados de generación, flujos y ángulos
        # se deuvlve m_cons ya que tiene en cuenta las restricciones reales de las lineas.
        return m_cons, solGen, solFlujos, solAngulos, solLMP

    # En caso de que no se encuentre solución a la optimización, se mostrará en pantalla el error
    else
        println("ERROR: ", termination_status(m_cons))
    end

end