import networkx as nx
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

def read_graph_from_csv(nodes_file, edges_file):    
    # Crear un grafo vacío
    G = nx.Graph()
    try:
        # Leer datos de los nodos desde el CSV
        nodes_df = pd.read_csv(nodes_file, sep=';')
        # Añadir nodos con valores
        nodes_with_values = {int(row['BUS']): {"LMP": row['LMP']} for idx, row in nodes_df.iterrows()}
        for node, data in nodes_with_values.items():
            G.add_node(node, **data)
    except Exception as e:
        print(f"Error leyendo nodos: {e}")
        print(nodes_df)

    try:
        # Leer datos de las aristas desde el CSV
        edges_df = pd.read_csv(edges_file, sep=';')
        # Añadir aristas con valores (pesos)
        edges = [(int(row['F_BUS']), int(row['T_BUS']), row['LINE_CAPACITY']) for idx, row in edges_df.iterrows()]
        G.add_weighted_edges_from(edges)
    except Exception as e:
        print(f"Error leyendo aristas: {e}")
        print(edges_df)
    
    return G, nodes_with_values, edges

# Leer los datos
G, nodes_with_values, edges = read_graph_from_csv('Resultados/solLMP.csv', 'Resultados/solFlujosLineas.csv')

# Crear una figura y un eje
fig, ax = plt.subplots(figsize=(12, 10))  # Tamaño de figura ajustado

# Configurar el fondo de la figura
fig.patch.set_facecolor('white')  # Fondo blanco para la figura
ax.set_facecolor('lightgrey')  # Fondo gris claro para el área de gráficos

# Obtener los valores de los pesos de las aristas
weights = nx.get_edge_attributes(G, 'weight').values()

# Normalizar los pesos para que estén en el rango [0, 1]
norm = plt.Normalize(vmin=min(weights), vmax=max(weights))

# Crear un mapa de colores (colormap) invertido de verde a rojo
cmap = plt.cm.RdYlGn_r

# Elegir el diseño para el grafo
pos = nx.spring_layout(G, k=5, iterations=1000, seed=42)  # Ajusta 'k' y 'iterations' para mejorar la disposición

# Alternativas: Puedes probar con otros layouts si el diseño spring no es óptimo
# pos = nx.circular_layout(G)
# pos = nx.kamada_kaway_layout(G)
# pos = nx.shell_layout(G)

# Dibujar nodos
nx.draw_networkx_nodes(G, pos, node_color='lightblue', node_size=500, ax=ax)

# Dibujar aristas con colores basados en los pesos
for (u, v, d) in G.edges(data=True):
    weight = d['weight']
    # Dibujar líneas con un contorno negro para mejorar el contraste
    nx.draw_networkx_edges(G, pos, edgelist=[(u, v)], width=3, alpha=0.8, edge_color=[cmap(norm(weight))], ax=ax, style='solid')

# Añadir etiquetas a los nodos que incluyen el valor extra
labels = {node: f"{int(node)}\n{data['LMP']} €/MWh" for node, data in G.nodes(data=True)}
# Dibujar las etiquetas centradas en los nodos
nx.draw_networkx_labels(G, pos, labels=labels, font_size=10, font_color='black', ax=ax, verticalalignment='center', horizontalalignment='center')

# Mostrar la barra de colores
sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
sm.set_array([])
fig.colorbar(sm, ax=ax, label='Peso')

plt.title("Grafo con aristas coloreadas según el peso y valores de nodos")
plt.show()
