# Esta funcion devulve un modelo con el solver cuyo nombre es recibido como entrada.
# Entrada
#   solver: String que contiene el nombre del solver.
# Salida
#   modelo: Modelo creado con el solver seleccionado
function IncializarModelo(solver::String) 

    if solver == "Gurobi"   # en este caso, el solver Gurobi
        modelo = Model(Gurobi.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(modelo)

    elseif solver == "HiGHS"    # Para el solver HiGHS
        modelo = Model(HiGHS.Optimizer)
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(modelo)

    elseif solver == "Ipopt"    # Para el solver Ipopt
        modelo = Model(Ipopt.Optimizer)        
        # Se deshabilita las salidas por defecto que tiene el optimizador
        set_silent(modelo)

    else # En caso de error
        println("ERROR: Selección de solver en DC-OPF")
        modelo = 0
    end
    return modelo
end