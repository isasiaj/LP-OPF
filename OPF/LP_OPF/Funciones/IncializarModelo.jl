function IncializarModelo(solver) 

    if solver == "Gurobi"   # en este caso, el solver Gurobi
        m    = Model(Gurobi.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m)

    elseif solver == "HiGHS"    # Para el solver HiGHS
        m    = Model(HiGHS.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m)

    elseif solver == "Ipopt"    # Para el solver Ipopt
        m    = Model(Ipopt.Optimizer)        
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(m)


    else # En caso de error
        println("ERROR: Selección de solver en DC-OPF")
        m = 0
    end
    return m
end