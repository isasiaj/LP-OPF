function CalculoOPF_OTS(dLinea::DataFrame, dGen::DataFrame, dNodo::DataFrame, nL::Int, nG::Int, nN::Int, bMVA::Int, solver::String)
    # Optimización del sistema inicial.
    m_aux, _, _, _, _ = calculoOPF(IncializarModelo(solver), dLinea, dGen, dNodo, nL, nG, nN, bMVA)
    coste_inicial = objective_value(m_aux)

    aux_fixed_lines = fill(false, nL)
    if "fixed" in names(dLinea)
        for ii in 1:nL
            if dLinea.fixed[ii] == 1
                aux_fixed_lines[ii] = true
            end
        end 
    end
    _,_, _, _, Ls = calculoOPF_BinVar(IncializarModelo(solver), 
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

    modelo, coste_final, P_G, Pₗᵢₙₑ, θ, node_lmp, node_mec = CalculoOPF_LMP(dLinea_final, dGen, dNodo, nL, nG, nN, bMVA, solver)

    return modelo, dLinea_final, coste_inicial, coste_final, P_G, Pₗᵢₙₑ, θ, node_lmp, node_mec
end