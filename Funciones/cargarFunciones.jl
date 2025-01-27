# Se cargan todas las funciones creadas

include("./boot.jl")                # Inicializador para cargar todas las funciones

include("./limpiarTerminal.jl")     # Limpieza del terminal
include("./elegirOpcion.jl")        # Elección y confirmación de la opción por parte del usuario, dentro de una lisya
include("./extraerDatos.jl")        # EXtrae los datos del caso seleccionado y los guarda en SparseArrays
include("./selectEstudio.jl")       # Elección del caso que se quiere estudiar
include("./gestorResultados.jl")    # Gestiona el resultado obtenido de la optimización

include("../LP-OPF/LP_OPF.jl")      # Función del Linear Programming - Optimal Power Flow