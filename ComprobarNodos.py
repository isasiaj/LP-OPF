import pandas as pd
from math import pi

# Cargar datos de los archivos CSV
dfFlujo = pd.read_csv('Resultados\\solFlujosLineas.csv', sep=';')
dfGen = pd.read_csv('Resultados\\solGeneradores.csv', sep=';')
dfDataNode = pd.read_csv('Casos\\pglib_opf_case30_ieee\\datosNodos.csv', sep=';')

# Extraer columnas específicas
# Supongamos que 'columna1' y 'columna2' son las columnas de archivo1.csv
# Y que 'columna3' es la columna de archivo2.csv
try:
    cLinea = dfFlujo['FLUJO']
    cF_linea = dfFlujo['fbus']
    cT_linea = dfFlujo['tbus']
    cGen = dfGen['PGEN']
    cNode_Gen = dfGen['bus']
    cDemand = dfDataNode['Pd']
except:
    print(dfGen)

print(f"Demanda total {cDemand.sum()} ==  Suma generadoeres {cGen.sum()}\n\n")

resultado = []
for ii in range(len(cDemand)):
    sum_aux = 0
    for jj in range(len(cLinea)):
        if cF_linea[jj] == ii + 1:
            sum_aux += cLinea[jj]
        elif cT_linea[jj] == ii + 1:
            sum_aux -= cLinea[jj]

    resultado.append(sum_aux)

# Imprimir los resultados
for ii in range(len(cDemand)):
    gen_aux = 0
    for jj in range(len(cGen)):
        if cNode_Gen[jj] == ii+1:
            gen_aux += cGen[jj]
    print(f"Node {ii+1}: Gen - Dem = {(gen_aux - cDemand[ii]):.2f}, Flujo saliente = {resultado[ii]:.2f}")

