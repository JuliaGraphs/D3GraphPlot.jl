using LightGraphs, D3GraphPlot

g = Graph(3)

add_edge!(g, 1, 2)
add_edge!(g, 2, 3)
add_edge!(g, 3, 1)

# d3BlinkPlot(g)
d3AtomPlot(g)


