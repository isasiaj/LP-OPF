# Está funcion calcula el OPF de un sistema que recibe como datos de entrada.
# Devulve el los resultados del OPF y los diferentes componentes del LMP.
#
# Entrada
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
#   coste:      Coste total optimo
#   P_G:        Lista solución optima, generadores
#   Pₗᵢₙₑ:       Lista solución optima, lineas
#   θ:          Lista solución optima, angulo de los nodos
#   node_lmp:   Lista solución optima, precios marginales locales
#   node_mec:   Lista precios locales si no hubiera congestion
function CalculoOPF_LMP(dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nL::Int, nG::Int, nN::Int, bMVA::Int, solver::String)

    # Optimización del sistema.
    Codigo_Fin, coste, P_G, Pₗᵢₙₑ, θ, node_lmp = calculoOPF(solver, dLinea, dGen, dNodo, nL, nG, nN, bMVA)
    
    # Se modifican las lineas de manera que la potencia máxima es igual a la demanda total.
    # Se usa para calcular cual seria el LMP si no hubiera congestion en las lineas.
    dLinea_no_cons = copy(dLinea)
    Demanda_total  = round(Int, sum(dNodo.Pd))
    for ii in 1:nL
        dLinea_no_cons.rateA[ii] =  Demanda_total
    end
    # Optimización sin congestión en las lineas.
    _, _, _, _, _, node_mec = calculoOPF(solver, dLinea_no_cons, dGen, dNodo, nL, nG, nN, bMVA)

    return Codigo_Fin, coste, P_G, Pₗᵢₙₑ, θ, node_lmp, node_mec
end