
module D3GraphPlot

using LightGraphs, JSON, Blink, Atom

function graphtojsonstring(g::Graph)
    data = Dict()

    data["nodes"] = []
    for v in 1:nv(g)
        push!(data["nodes"], Dict("name" => v))
    end

    data["edges"] = []
    for e in edges(g)
        push!(data["edges"], Dict("source" => (src(e)-1), "target" => (dst(e)-1)))
    end

    data_json_string = JSON.json(data)
    # print(data_json_string)
    return data_json_string
end

function d3BlinkPlot(g::Graph)
    #load javascript function drawgraph() that is based on d3
    url = string("file://", dirname(@__FILE__), "/../resources/index.html")
    w = Window()
    loadurl(w, url)

    #prepare the dataset to be passed to drawgraph()
    data_json_string = graphtojsonstring(g)

    #call the javascript function drawgraph()
    @js w (drawgraph($data_json_string);)
end

function d3AtomPlot(g::Graph)
    #load javascript function drawgraph() that is based on d3 in the pane Plots
    url = string("file://", dirname(@__FILE__), "/../resources/index.html")

    #prepare the dataset to be passed to drawgraph()
    data_json_string = graphtojsonstring(g)

    #call the javascript function drawgraph()
    runarg = string("drawgraph('", data_json_string, "')")
    Atom.@msg ploturlandrun(url, runarg)
end

export d3BlinkPlot, d3AtomPlot

end # module
