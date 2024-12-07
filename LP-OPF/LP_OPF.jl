# PENDIENTE:
# Latex (esquema) - Overleaf

# Explicar en caso de considerar pérdidas

include("./Funciones/gestorDatosLP.jl")
include("./Funciones/matrizSusceptancia.jl")
include("./Funciones/calculoOPF.jl")
include("./Funciones/calculoOPF_OTS_BinVar.jl")
include("./Funciones/calculoOPF_serviceOTS_Relax.jl")
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
    # Calculate_LineSW: Tipo de optimización elegida por el usuario
    

    ########## INICIALIZAR MODELO ##########
    # Se crea el modelo "m_cons" con optimizador elegido,
    # y el modelo "m_no_cons".
    m_cons    = IncializarModelo(solver)
    m_no_cons = IncializarModelo(solver)

    if Calculate_LineSW == "No OTS"
        # Optimización con modelo de restricción por potencia maxima en las lineas.
        m_cons, P_G, Pₗᵢₙₑ, θ, node_lmp = calculoOPF(m_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA)

        # Se modifican datos de lineas de manera que la potencia máxima es igual a la demanda total 
        # del sistema, se usa para calcular cual seria el LMP en este caso.
        dLinea_no_cons= copy(dLinea)
        for ii in 1:nL
            dLinea_no_cons.rateA[ii] =  round(Int, sum(dNodo.Pd))
        end
        # Optimización sin congestión en las lineas.
        m_no_cons, _, _, _, node_mec = calculoOPF(m_no_cons, dLinea_no_cons, dGen, dNodo, nL, nG, nN, bMVA)

        # Se copia varible para que la estructura de salida sea la misma en todos los casos
        dLinea_final= copy(dLinea)
    elseif Calculate_LineSW == "OTS simple"
        m_no_cons,_, _, _, Ls = calculoOPF_BinVar(m_no_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA, [false for ii in 1:nL])
        dLinea_final = copy(dLinea) 
        for ii in 1:nL
            dLinea_final.status[ii] = round(Int, value(Ls[ii]))
        end
        # Optimización con modelo de restricción por potencia maxima en las lineas.
        m_cons, P_G, Pₗᵢₙₑ, θ, node_lmp = calculoOPF(m_cons, dLinea_final, dGen, dNodo, nL, nG, nN, bMVA)
    elseif Calculate_LineSW == "OTS precios con Dif. fnc objetivo 1"
        # se calcula una primera optimizacion con varible binarias para el estado de las lineas.
        m_cons, _, _, _, _ = calculoOPF(m_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA)

        coste_base = round(objective_value(m_cons), digits = 2)

        m_cons = nothing
        m_cons = IncializarModelo(solver)

        m_cons, P_G, Pₗᵢₙₑ, θ, Ls = calculoOPF_BinVar(m_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA, [false for ii in 1:nL])

        dLinea_final = copy(dLinea)
        
        for ii in 1:nL
            dLinea_final.status[ii] = round(Int, value(Ls[ii]))
        end

        OTSservice = []
        for ii in 1:nL

            if dLinea.status[ii] != dLinea_final.status[ii]

                dLinea_aux = copy(dLinea)

                dLinea_aux.status[ii] = dLinea_final.status[ii]

                m_no_cons, _, _, _, _ = calculoOPF(m_no_cons, dLinea_aux, dGen, dNodo, nL, nG, nN, bMVA)

                push!(OTSservice, coste_base - round(objective_value(m_no_cons), digits = 2))

                m_no_cons = nothing
                m_no_cons = IncializarModelo(solver)
            else
                push!(OTSservice, 0)
            end
        end

        # Se crea unos nuevos datos de lineas de manera que la potencia maxima es igual a la demanda total 
        # del sistema.
        dLinea_no_cons = copy(dLinea_final)
        for ii in 1:nL
            dLinea_no_cons.rateA[ii] = round(Int, sum(dNodo.Pd))
        end
        # Se elimina la restriccion de potencia maxima en las lineas para calculas los costes por congestion
        m_no_cons, _, _, _, node_mec = calculoOPF(m_no_cons, dLinea_no_cons, dGen, dNodo, nL, nG, nN, bMVA)

    elseif Calculate_LineSW == "OTS precios con Dif. fnc objetivo 2"
        # se calcula una primera optimizacion con varible binarias para el estado de las lineas.
        m_cons, _, _, _, _ = calculoOPF(m_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA)

        coste_inicial = round(objective_value(m_cons), digits = 2)

        m_cons = nothing
        m_cons = IncializarModelo(solver)

        m_cons, _, _, _, Ls = calculoOPF_BinVar(m_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA, [false for ii in 1:nL])

        coste_base = round(objective_value(m_cons), digits = 2)

        dLinea_aux2 = copy(dLinea)
        
        for ii in 1:nL
            dLinea_aux2.status[ii] = round(Int, value(Ls[ii]))
        end

        OTSservice = []
        for ii in 1:nL
            if dLinea.status[ii] != dLinea_aux2.status[ii]
                dLinea_aux = copy(dLinea_aux2)

                dLinea_aux.status[ii] = dLinea.status[ii]

                m_no_cons, _, _, _, _ = calculoOPF(m_no_cons, dLinea_aux, dGen, dNodo, nL, nG, nN, bMVA)

                coste_aux = round(objective_value(m_no_cons), digits = 2)
                push!(OTSservice, coste_aux - coste_base)

                m_no_cons = nothing
                m_no_cons = IncializarModelo(solver)
            else
                push!(OTSservice, 0)
            end
        end

        dLinea_final = copy(dLinea)
        
        for ii in 1:nL
            if OTSservice[ii] != 0
                dLinea_final.status[ii] =  dLinea_aux2.status[ii]
            end
        end 

        m_cons = nothing
        m_cons = IncializarModelo(solver)

        m_cons,  P_G, Pₗᵢₙₑ, θ, node_lmp = calculoOPF(m_cons, dLinea_final, dGen, dNodo, nL, nG, nN, bMVA)

        # Se crea unos nuevos datos de lineas de manera que la potencia maxima es igual a la demanda total 
        # del sistema.
        dLinea_no_cons = copy(dLinea_final)
        for ii in 1:nL
            dLinea_no_cons.rateA[ii] = round(Int, sum(dNodo.Pd))
        end
        # Se elimina la restriccion de potencia maxima en las lineas para calculas los costes por congestion
        m_no_cons, _, _, _, node_mec = calculoOPF(m_no_cons, dLinea_no_cons, dGen, dNodo, nL, nG, nN, bMVA)

    elseif Calculate_LineSW == "OTS precios con duales"
        # Se calcula una primera optimizacion Con el estado inicial de las lineas, esto se usa para calcular el coste inicial.
        m_no_cons, P_G_ini, Pₗᵢₙₑ_ini, θ_ini, _ = calculoOPF(m_no_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA)
        coste_base = round(objective_value(m_no_cons), digits = 2)

        #Se calcula la topología de la red que minimiza el coste.
        m_no_cons = nothing
        m_no_cons = IncializarModelo(solver) # Se resetea el modelo para evitar errores
        aux = fill(false, nL)
        if "fixed" in names(dLinea)
            for ii in 1:nL
                if dLinea.fixed[ii] == 1
                    aux[ii] = true
                end
            end 
        end

        m_no_cons, _, _, _, Ls = calculoOPF_BinVar(m_no_cons, dLinea, dGen, dNodo, nL, nG, nN, bMVA, aux)

        # Se crea la estrcutura dLinea_final que contendra los datos de las lineas utilizadas en la red optima.
        # se modifica la columna status para conectar y desconectar lineas
        dLinea_final = copy(dLinea) 
        for ii in 1:nL
            dLinea_final.status[ii] = round(Int, value(Ls[ii]))
        end
        #Calculo OPF con la topología optima.
        m_cons, P_G, Pₗᵢₙₑ, θ, node_lmp = calculoOPF(m_cons, dLinea_final, dGen, dNodo, nL, nG, nN, bMVA)

        # se crea con solver "Ipopt" al ser necesario usar un solver que soporte modelos no lineales.
        m_no_cons = nothing
        m_no_cons = IncializarModelo("Ipopt") 

        # Calculo d como influye en coste modificar el estado de las lineas.
        _, _, _, _, _, OTSservice, OTSservice2 = calculoOPF_serviceOTS_Relax(m_no_cons, dLinea_final, dLinea, dGen, dNodo, nL, nG, nN, bMVA, [value(P_G_ini[ii]) for ii in 1:nG], [value(Pₗᵢₙₑ_ini[ii]) for ii in 1:nL], [value(θ_ini[ii]) for ii in 1:nN])

        # Se crea unos nuevos datos de lineas de manera que la potencia maxima es igual a la demanda total del sistema.
        dLinea_aux = copy(dLinea_final)
        for ii in 1:nL
            dLinea_aux.rateA[ii] = round(Int, sum(dNodo.Pd))
        end
        # Se elimina la restriccion de potencia maxima en las lineas para calculas los costes por congestion
        m_no_cons = nothing
        m_no_cons = IncializarModelo(solver) # Se resetea el modelo para evitar errores
        m_no_cons, _, _, _, node_mec = calculoOPF(m_no_cons, dLinea_aux, dGen, dNodo, nL, nG, nN, bMVA)
    end

    # Guardar solución en DataFrames en caso de encontrar solución óptima en cada modelo.
    if ((termination_status(m_cons) == OPTIMAL || termination_status(m_cons) == LOCALLY_SOLVED || termination_status(m_cons) == ITERATION_LIMIT))


        if !@isdefined(P_G)
            P_G = zeros(nG)  # Crea un array de ceros de tamaño nG
        end

        if !@isdefined(OTSservice)
            OTSservice = zeros(nL)  # Crea un array de ceros de tamaño nL
        end

        if !@isdefined(OTSservice2)
            OTSservice2 = zeros(nL)  # Crea un array de ceros de tamaño nL
        end

        if !@isdefined(node_lmp)
            node_lmp = zeros(nN)  # Crea un array de ceros de tamaño nN
        end

        if !@isdefined(node_mec)
            node_mec = zeros(nN)  # Crea un array de ceros de tamaño nN
        end

        if !@isdefined(Pₗᵢₙₑ)
            Pₗᵢₙₑ = zeros(nL)  # Crea un array de ceros de tamaño nL
        end
        
        if !@isdefined(θ)
            θ = zeros(nN)  # Crea un array de ceros de tamaño nN
        end

        # solGen recoge los valores de la potencia generada de cada generador de la red
        # Primera columna: nodo
        # Segunda columna: valor lo toma de la variable "P_G" (está en pu y se pasa a MVA) del generador de dicho nodo.
        solGen = DataFrames.DataFrame(bus = (dGen.bus), PGEN = (round.(P_G.* bMVA, digits = 2)))

        # solFlujos recoge el flujo de potencia que pasa por todas las líneas
        # Primera columna: nodo del que sale
        # Segunda columna: nodo al que llega
        # Tercera columna: valor del flujo de potencia en la línea
        # Cuarta  columna: valor en tanto por uno de la satuaracion de la linea:  potencia en la línea / potencia maxima en la linea
        solFlujos = DataFrames.DataFrame(fbus = Int[], tbus = Int[], FLUJO = Float64[], LINE_CAPACITY = Float64[], State0 = Int[], State1 = Int[], OTS1 = Float64[], OTS2 = Float64[])

        for ii in 1:nL
            # Se crean dos casos para que siempre la potencia de positiva, invirtiendo nodos fbus y tbus
            if Pₗᵢₙₑ[ii] >= 0
                push!(solFlujos, Dict(:fbus => (dLinea_final.fbus[ii]),
                                      :tbus => (dLinea_final.tbus[ii]), 
                                      :FLUJO => round(Pₗᵢₙₑ[ii] * bMVA, digits = 2), 
                                      :LINE_CAPACITY => round((Pₗᵢₙₑ[ii] * bMVA)/dLinea_final.rateA[ii], digits = 3),
                                      :State0 => dLinea.status[ii],
                                      :State1 => dLinea_final.status[ii],
                                      :OTS1 => OTSservice[ii],
                                      :OTS2 => OTSservice2[ii]))

            else
                push!(solFlujos, Dict(:fbus => dLinea_final.tbus[ii], 
                                      :tbus => dLinea_final.fbus[ii], 
                                      :FLUJO => round(-Pₗᵢₙₑ[ii] * bMVA, digits = 2), 
                                      :LINE_CAPACITY => round((-Pₗᵢₙₑ[ii] * bMVA)/dLinea_final.rateA[ii], digits = 3),
                                      :State0 => dLinea.status[ii],
                                      :State1 => dLinea_final.status[ii],
                                      :OTS1 => OTSservice[ii],
                                      :OTS2 => OTSservice2[ii]))
            end
        end

        # solAngulos recoge el desfase de la tensión en los nodos
        # Primera columna: nodo
        # Segunda columna: valor del desfase en grados
        solAngulos = DataFrames.DataFrame(bus_i = Int[], GRADOS = Float64[])
        for ii in 1:nN
            push!(solAngulos, Dict(:bus_i => ii, :GRADOS => round(rad2deg(θ[ii]), digits = 2)))
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
        print(m_cons)
        println("ERROR: ", termination_status(m_cons))
    end

end