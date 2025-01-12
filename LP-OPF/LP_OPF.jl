include("./Funciones/gestorDatosLP.jl")
include("./Funciones/matrizSusceptancia.jl")
include("./Funciones/calculoOPF.jl")
include("./Funciones/calculoOPF_OTS_BinVar.jl")
include("./Funciones/CalculateServiceOTS_dual.jl")
include("./Funciones/IncializarModelo.jl")
include("./Funciones/CalculoOPF_LMP.jl")
include("./Funciones/CalculoOPF_OTS.jl")

# Esta funcion se encarga de filtrar el tipo de optimizacion elegida.
# Hay diferentes casos para los diferentes tipos de simulaciones que se pueden realizar.
#
# Entrada
#   dLinea:           Datos de las líneas
#   dGen:             Datos de los generadores
#   dNodo:            Datos de la demanda
#   nL:               Número de líneas
#   nG:               Número de generadores
#   nN:               Número de nodos
#   bMVA:             Potencia base
#   solver:           Solver a utilizar
#   Calculate_LineSW: Tipo de optimización elegida por el usuario
# Salida
#   Codigo_Fin:       Estado en el que termino la optimizacion
#   coste_inicial:    Coste optimo total del sistema con la topologia inicial
#   coste_final:      Coste optimo total del sistema con la topologia final
#   solGen:           DataFrame con la solución optima, generadores
#   solFlujos:        DataFrame con la solución optima, lineas
#   solAngulos:       DataFrame con la solución optima, angulo de los nodos
#   solLMP:           DataFrame con la solución optima, precios marginales locales
function LP_OPF(dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nL::Int, nG::Int, nN::Int, bMVA::Int, solver::String, Calculate_LineSW::String) 

    if Calculate_LineSW == "No OTS"
        # Este método no optimiza la topología de la red
        # LP-OPF con precios marginales locales pero con una topología fija.
        Codigo_Fin, coste_inicial, P_G, Pₗᵢₙₑ, θ, node_lmp, node_mec = CalculoOPF_LMP(dLinea, dGen, dNodo, nL, nG, nN, bMVA, solver)

        # Sin OTS el coste inicial y final es el mismo, la topología no se modifica.
        coste_final = coste_inicial
        dLinea_final = copy(dLinea)

    else
        # Se calcula el LP-OPF con los datos de la red selecionados por el usuario
        # Se optimizara la topología usando los datos de la red.
        # 
        # En el archvo del caso "datosLineas.csv", sepuede añadir una nueva columna de nombre "fixed"
        # En esta columna se puede fijar el estado de una linea al inicial, y evitar que se conecte/desconecte
        # por el algoritmo del OTS.

        Codigo_Fin, 
        dLinea_final, 
        coste_inicial, 
        coste_final, 
        P_G, 
        Pₗᵢₙₑ, 
        θ, 
        node_lmp, 
        node_mec = CalculoOPF_OTS(
            dLinea, 
            dGen, 
            dNodo, 
            nL, 
            nG, 
            nN, 
            bMVA, 
            solver
            )

        if Calculate_LineSW == "OTS simple"
            # Este método no reliza precios del OTS como servicio.
        elseif Calculate_LineSW == "OTS precios con Dif. fnc objetivo 1"
            # Este método realiza un calculo de precios de OTS por diferencias de coste total
            # respecto al coste de optimizar sistema inicial recibido, sin OTS.
            # Partiendo del sistema inicial se cambia el estado de las lineas una por una, en las lineas seleccionas por el OTS
            # Precio modificar linea ii = coste_inicial - Coste_modificando_ii
            OTSservice = []
            for ii in 1:nL

                if dLinea.status[ii] != dLinea_final.status[ii]
                    dLinea_aux = copy(dLinea)
                    dLinea_aux.status[ii] = dLinea_final.status[ii]

                    _, coste_aux,  _, _, _, _ = calculoOPF(solver, dLinea_aux, dGen, dNodo, nL, nG, nN, bMVA)

                    push!(OTSservice, coste_inicial - coste_aux)

                else
                    push!(OTSservice, 0)
                end
            end

        elseif Calculate_LineSW == "OTS precios con Dif. fnc objetivo 2"
            # Este método realiza un calculo de precios de OTS por diferencias de coste total
            # respecto al coste total del sistema con la topología optima
            # Partiendo del sistema optimo se cambia al estado inicial las lineas una a una
            # Precio modificar linea ii = Coste_sin_modifcar_ii - coste_final
            OTSservice = []
            for ii in 1:nL
                if dLinea.status[ii] != dLinea_final.status[ii]
                    dLinea_aux = copy(dLinea_final)
                    dLinea_aux.status[ii] = dLinea.status[ii]

                    _, coste_aux, _, _, _, _ = calculoOPF(solver, dLinea_aux, dGen, dNodo, nL, nG, nN, bMVA)

                    push!(OTSservice, coste_aux - coste_final)

                else
                    push!(OTSservice, 0)
                end
            end

        elseif Calculate_LineSW == "OTS precios con duales"
            # Calulo de los precios del servicio de OTS usando duales:
            # Lineas a conectar a la red: 
            #   El precio de Modificar el estado de estas lineas se calcula usando duales, multiplicados por la potencia optima en esta linea
            # 
            # Lineas a desconectar a la red:
            #   El precio se calcula ___________________________

            # Optimizacion lineal auxiliar para facilitar la semilla a la siguiente.
            # Con esto facilitamos que la siguiente optimizacion, que es no linel, llegue a lo solucion optima global.
            _, _, P_G_ini, Pₗᵢₙₑ_ini, θ_ini, _ = calculoOPF(solver, dLinea, dGen, dNodo, nL, nG, nN, bMVA)

            # Calculo de como influye en coste modificar el estado de las lineas.
            OTSservice = CalculateServiceOTS_dual("Ipopt", 
                dLinea_final, 
                dLinea, 
                dGen, 
                dNodo, 
                nL, 
                nG, 
                nN, 
                bMVA, 
                [value(P_G_ini[ii]) for ii in 1:nG], 
                [value(Pₗᵢₙₑ_ini[ii]) for ii in 1:nL], 
                [value(θ_ini[ii]) for ii in 1:nN])

            # El coste deuvlto por la funcion anterior es en €/MW
            OTSservice = OTSservice .* Pₗᵢₙₑ
        end
    end

    # Guardar solución en DataFrames en caso de encontrar solución óptima en cada modelo.
    if ((Codigo_Fin == OPTIMAL || Codigo_Fin == LOCALLY_SOLVED || Codigo_Fin == ITERATION_LIMIT))

    ########## Aquí se rellenen a ceros las variables no usadas en algunos de los metodos anteriores ##########

        if !@isdefined(OTSservice)
            OTSservice = zeros(nL)  # Crea un array de ceros de tamaño nL
        end

    ########## Se rellenen DataFrames con los resultados finales de la optimización ##########

        # solGen recoge los valores de la potencia generada de cada generador de la red
        # Primera columna, BUS: nodo donde se encuntra el generador
        # Segunda columna, PGEN: valor lo toma de la variable "P_G" (está en pu y se pasa a MVA) del generador de dicho nodo.
        solGen = DataFrames.DataFrame(BUS = (dGen.bus), PGEN = (round.(P_G.* bMVA, digits = 2)))

        # solFlujos recoge el flujo de potencia que pasa por todas las líneas
        # Primera columna, FBUS: nodo potencia saliente
        # Segunda columna, TBUS: nodo potencia entrante
        # Tercera columna, POWER: valor del flujo de potencia en la línea en MW
        # Cuarta  columna, LINE_CAPACITY: potencia en la línea / potencia maxima en la linea
        # Quinta  columna, STATUS_0: Estado inicial de la linea.
        # Sexta   columna, STATUS_1: Estado final de la linea, depues de la optimización.
        # Septima columna, OTS_PRICE: Precio por conmutar la linea.
        solFlujos = DataFrames.DataFrame(FBUS = Int[], TBUS = Int[], FLUJO = Float64[], LINE_CAPACITY = Float64[], STATUS_0 = Int[], STATUS_1 = Int[], OTS_PRICE = Float64[])
        for ii in 1:nL
            push!(solFlujos, 
                Dict(:FBUS => (dLinea_final.fbus[ii]), 
                    :TBUS => (dLinea_final.tbus[ii]), 
                    :FLUJO => round(Pₗᵢₙₑ[ii] * bMVA, digits = 2), 
                    :LINE_CAPACITY => round((Pₗᵢₙₑ[ii] * bMVA)/dLinea_final.rateA[ii], digits = 3),
                    :STATUS_0 => dLinea.status[ii],
                    :STATUS_1 => dLinea_final.status[ii],
                    :OTS_PRICE => OTSservice[ii]))
        end

        # solAngulos recoge el desfase de la tensión en los nodos
        # Primera columna: nodo
        # Segunda columna: valor del desfase en grados
        solAngulos = DataFrames.DataFrame(BUS = Int[], GRADOS = Float64[])
        for ii in 1:nN
            push!(solAngulos, Dict(:BUS => ii, :GRADOS => round(rad2deg(θ[ii]), digits = 2)))
        end

        # solLMP recoge los precios marginales locales y sus componentes en cada nodo.
        # Primera columna, BUS: nodo sobre el que se obtienen los precios.
        # Segunda columna, LMP: Precio marginal local en cada de la red
        # Tercera columna, MEC: Componente de energia del LMP, sin tener en cuenta costes por congestion o perdidas en las lineas.
        # Cuarta  columna, MCC: Componete de congestion del precio marginal, como afecta la congestion en las lineas sobre el precio marginal en ese nodo.
        solLMP = DataFrames.DataFrame(BUS = Int[], LMP = Float64[], MEC = Float64[], MCC = Float64[])
        for ii in 1:nN
            # Marginal price of energy, €/MWh
            push!(solLMP, Dict(:BUS => ii, 
                            :LMP => round(node_lmp[ii], digits = 3),
                            :MEC => round(node_mec[ii], digits = 3),
                            :MCC => round(node_lmp[ii] - node_mec[ii], digits = 3)))
        end

        return Codigo_Fin, coste_inicial, coste_final, solGen, solFlujos, solAngulos, solLMP

    else # En caso de que no se encuentre solución a la optimización, se mostrará en pantalla el error
        println("ERROR: ", Codigo_Fin)
    end

end