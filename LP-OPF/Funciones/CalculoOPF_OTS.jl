# Está funcion calcula el OPF de un sistema que recibe como datos de entrada, 
# optimizando su topología.
# Devulve el los resultados del OPF, los diferentes componentes del LMP 
# y los datos de la red optimizada
#
# Entrada
#   dLinea:         Datos de las líneas
#   dGen:           Datos de los generadores
#   dNodo:          Datos de la demanda
#   nL:             Número de líneas
#   nG:             Número de generadores
#   nN:             Número de nodos
#   bMVA:           Potencia base
#   solver:         Solver a utilizar
# Salida
#   Codigo_Fin:     Estado en el que termino la optimizacion
#   dLinea_final:   Datos finales de la red, una vez optimizada la topología
#   coste_inicial:  Coste total de generación inicial, antes de optimizar la topología
#   coste_final:    Coste total de generación final, una vez optimizada la topología
#   P_G:            Lista solución optima, generadores
#   Pₗᵢₙₑ:           Lista solución optima, lineas
#   θ:              Lista solución optima, angulo de los nodos
#   node_lmp:       Lista solución optima, precios marginales locales
#   node_mec:       Lista precios locales si no hubiera congestion
function CalculoOPF_OTS(dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nL::Int, nG::Int, nN::Int, bMVA::Int, solver::String)
    # Optimización del sistema inicial.
    _, coste_inicial, _, _, _, _ = calculoOPF(solver, dLinea, dGen, dNodo, nL, nG, nN, bMVA)

    aux_fixed_lines = fill(false, nL)
    if "fixed" in names(dLinea)
        for ii in 1:nL
            if dLinea.fixed[ii] == 1
                aux_fixed_lines[ii] = true
            end
        end 
    end
    Ls = calculoOPF_BinVar(solver, 
        dLinea, 
        dGen, 
        dNodo, 
        nL, 
        nG, 
        nN, 
        bMVA, 
        aux_fixed_lines)
    
    dLinea_final = copy(dLinea) 
    for ii in 1:nL
        dLinea_final.status[ii] = round(Int, value(Ls[ii]))
    end

    Codigo_Fin, coste_final, P_G, Pₗᵢₙₑ, θ, node_lmp, node_mec = CalculoOPF_LMP(dLinea_final, dGen, dNodo, nL, nG, nN, bMVA, solver)

    return Codigo_Fin, dLinea_final, coste_inicial, coste_final, P_G, Pₗᵢₙₑ, θ, node_lmp, node_mec
end