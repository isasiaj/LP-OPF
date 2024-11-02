import pandas as pd
from math import pi

# Cargar datos de los archivos CSV
dfFlujo = pd.read_csv('Resultados\\solFlujosLineas.csv', sep=';')
dfAng = pd.read_csv('Resultados\\solAngulos.csv', sep=';')
dfLinea = pd.read_csv('Casos\\pglib_opf_case30_ieee\\datosLineas.csv', sep=';')

# Extraer columnas específicas
# Supongamos que 'columna1' y 'columna2' son las columnas de archivo1.csv
# Y que 'columna3' es la columna de archivo2.csv
try:
    cLinea = dfFlujo['FLUJO']
    cState = dfFlujo['State1']
    cF = dfLinea['fbus']
    cT = dfLinea['tbus']
    cAng = dfAng['GRADOS']
    cX = dfLinea['x']
except Exception as e:
    print(dfLinea.head())
    print(dfLinea.columns)
    print(e)

# resultado =[]
# for ii in range(len(cX)):
#     resultado.append(cX.iloc(ii)*(cAng.iloc(cF.iloc(ii)-1) - cAng.iloc(cT.iloc(ii)-1)))
resultado = (cAng.iloc[cF - 1].values - cAng.iloc[cT - 1].values)*pi/180*100/cX * cState

# Comparar el resultado con columna2 de archivo1.csv
comparacion = resultado == cLinea

# Imprimir los resultados
for i in range(len(cX)):
    print(f"Fila {i}: Test = {resultado[i]:.2f}, OPF = {cLinea[i]}, ¿Iguales? {comparacion[i]}")

# # Guardar la comparación en un nuevo CSV si es necesario
# cX['Comparacion'] = comparacion
# csv1.to_csv('resultado_comparacion.csv', index=False)
