# ----------- #
# Blink setup #
# ----------- #

const _js_d3_path = "http://d3js.org/d3.v3.min.js"
const _js_jquery_path = "https://ajax.googleapis.com/ajax/libs/jquery/3.2.0/jquery.min.js"
const _autoresize = [true]

type Plot
    graph_json_string::String
    divid::Base.Random.UUID
end

type ElectronDisplay
    divid::Base.Random.UUID
    w::Nullable{Any}
end

type SyncPlot
    plot::Plot
    view::ElectronDisplay
end

typealias ElectronPlot SyncPlot

ElectronDisplay(divid::Base.Random.UUID) = ElectronDisplay(divid, Nullable())
ElectronDisplay(p::Plot) = ElectronDisplay(p.divid)
ElectronPlot(p::Plot) = ElectronPlot(p, ElectronDisplay(p.divid))

# define some core methods on the display

"""
Return true if the display has been initialized and is still open, else false
"""
isactive(ed::ElectronDisplay) = isnull(ed.w) ? false : Blink.active(get(ed.w))

"""
If the display is active, close the window
"""
Base.close(ed::ElectronDisplay) = isactive(ed) && close(get(ed.w))


"Variable we can query to see if the plot has finished rendering"
function done_var(ed::ElectronDisplay)
    Symbol("done_$(split(string(ed.divid), "-")[1])")
end

"variable to store the svg data in"
function svg_var(ed::ElectronDisplay)
    Symbol("svg_$(split(string(ed.divid), "-")[1])")
end

"""
Return true if the display is active and the plot has finished rendering, else
false
"""
function Base.isready(ed::ElectronDisplay)
    !isactive(ed) && return false
    Blink.js(ed, done_var(ed))
end

# helper method to obtain a Blink window, given some options
get_window(opts::Dict) = Juno.isactive() ? Juno.Atom.blinkplot() : Window(opts)

"""
Initialize a Blink window for displaying the a plot. This will return an
existing window if it has been initialized and is still active, otherwise it
creates one.
Part of the creation process here is loading the plotly javascript.
"""
function get_window(ed::ElectronDisplay; kwargs...)
    if !isnull(ed.w) && active(get(ed.w))
        w = get(ed.w)
    else
        w = get_window(Dict(kwargs))
        ed.w = w
        # load the js here
        Blink.loadjs!(w, _js_d3_path)
        # Blink.loadjs!(w, _mathjax_cdn_path)
        Blink.js(w, :($(done_var(ed)) = false))
        Blink.js(w, :($(svg_var(ed)) = undefined))

        # make sure plotly has been loaded
        done = false
        while !done
            try
                @js w d3
                # println("d3 was loaded")
                done = true
            catch e
                continue
            end
        end
    end
    w
end

# the corresponding methods for ElectronPlot can (for the most part)
# just forward on to the view
Base.isready(p::ElectronPlot) = isready(p.view)

done_var(p::ElectronPlot) = done_var(p.view)
svg_var(p::ElectronPlot) = svg_var(p.view)

"""
Close the plot window (if active) and reset the fields and reset the `w` field
on the display to be `Nullable()`.
"""
function Base.close(p::ElectronPlot)
    close(p.view)
    p.view.w = Nullable()
    nothing
end

"""
Use the plot width and height to open a window of the correct size
"""
function get_window(p::ElectronPlot; kwargs...)
    w, h =  1000, 1000 #size(p.plot)
    get_window(p.view; width=w, height=h, kwargs...)
end

Base.display(p::ElectronPlot; show = true, resize::Bool=false) = #_autoresize[1]) =
  display_blink(p; show = show, resize = resize)

function display_blink(p::ElectronPlot; show=true, resize::Bool=false) #_autoresize[1],)
    w = get_window(p, show=show)

    done = done_var(p)
    svg = svg_var(p)

    # if !resize assuming no resize
        # code = """
        # <script>
        # (function(){
        # var gd = Plotly.d3.select("body")
        #     .append("div")
        #     .attr("id", "$(p.plot.divid)")
        #     .node();
        # var plot_json = $(json(p.plot));
        # var data = plot_json.data;
        # var layout = plot_json.layout;
        # Plotly.newPlot(gd, data, layout).then(function(gd) {
        #          $(done) = true;
        #          return Plotly.toImage(gd, {"format": "svg"});
        #     }).then(function(data) {
        #         var svg_data = data.replace(/^data:image\\/svg\\+xml,/, "");
        #         $(svg) = decodeURIComponent(svg_data);
        #      });
        #  })();
        # </script>
        # """

        code = """
        <!-- <p>yo0<p> -->
        <script>
            // var p = document.getElementsByTagName("p")[0]
            // p.innerHTML = p.innerHTML + "<p>yo1</p>"

            // var WIDTH_IN_PERCENT_OF_PARENT = 100
            // var HEIGHT_IN_PERCENT_OF_PARENT = 100;

            var w = Math.max(
                document.documentElement["clientWidth"],
                document.body["scrollWidth"],
                document.documentElement["scrollWidth"],
                document.body["offsetWidth"],
                document.documentElement["offsetWidth"]
            );

            var h = Math.max(
                document.documentElement["clientHeight"],
                document.body["scrollHeight"],
                document.documentElement["scrollHeight"],
                document.body["offsetHeight"],
                document.documentElement["offsetHeight"]
            );

            var linkDistance=200;

            var colors = d3.scale.category10();

            //var yo = '$(p.plot.graph_json_string)'
            //p.innerHTML = p.innerHTML + "<p>"+yo+"</p>"

            var dataset = JSON.parse('$(p.plot.graph_json_string)')

            /*
            var dataset = {
                nodes: [
                    {name: 1},
                    {name: 2},
                    {name: 3}
                ],
                edges: [
                    {source: 0, target: 1},
                    {source: 0, target: 2},
                    {source: 1, target: 2}
                ]
            };*/

            var svg = d3.select("body").append("svg").attr({"width":w,"height":h});

            //            .attr({"width":WIDTH_IN_PERCENT_OF_PARENT + '%',
            //                   "height":HEIGHT_IN_PERCENT_OF_PARENT + %});

            var force = d3.layout.force()
                .nodes(dataset.nodes)
                .links(dataset.edges)
                .size([w,h])
                .linkDistance([linkDistance])
                .charge([-500])
                .theta(0.1)
                .gravity(0.05)
                .start();

            var edges = svg.selectAll("line")
              .data(dataset.edges)
              .enter()
              .append("line")
              .attr("id",function(d,i) {return 'edge'+i})
              //.attr('marker-end','url(#arrowhead)')
              .style("stroke","#ccc")
              .style("pointer-events", "none");

            var nodes = svg.selectAll("circle")
              .data(dataset.nodes)
              .enter()
              .append("circle")
              .attr({"r":15})
              .style("fill",function(d,i){return colors(i);})
              .call(force.drag)


            var nodelabels = svg.selectAll(".nodelabel")
               .data(dataset.nodes)
               .enter()
               .append("text")
               .attr({"x":function(d){return d.x;},
                      "y":function(d){return d.y;},
                      "class":"nodelabel",
                      "stroke":"black"})
               .text(function(d){return d.name;});

            var edgepaths = svg.selectAll(".edgepath")
                .data(dataset.edges)
                .enter()
                .append('path')
                .attr({'d': function(d) {return 'M '+d.source.x+' '+d.source.y+' L '+ d.target.x +' '+d.target.y},
                       'class':'edgepath',
                       'fill-opacity':0,
                       'stroke-opacity':0,
                       'fill':'blue',
                       'stroke':'red',
                       'id':function(d,i) {return 'edgepath'+i}})
                .style("pointer-events", "none");

            var edgelabels = svg.selectAll(".edgelabel")
                .data(dataset.edges)
                .enter()
                .append('text')
                .style("pointer-events", "none")
                .attr({'class':'edgelabel',
                       'id':function(d,i){return 'edgelabel'+i},
                       'dx':80,
                       'dy':0,
                       'font-size':10,
                       'fill':'#aaa'});

            edgelabels.append('textPath')
                .attr('xlink:href',function(d,i) {return '#edgepath'+i})
                .style("pointer-events", "none")
                //.text(function(d,i){return 'label '+i});
                ;


            svg.append('defs').append('marker')
                .attr({'id':'arrowhead',
                       'viewBox':'-0 -5 10 10',
                       'refX':25,
                       'refY':0,
                       //'markerUnits':'strokeWidth',
                       'orient':'auto',
                       'markerWidth':10,
                       'markerHeight':10,
                       'xoverflow':'visible'})
                .append('svg:path')
                    .attr('d', 'M 0,-5 L 10 ,0 L 0,5')
                    .attr('fill', '#ccc')
                    .attr('stroke','#ccc');


            force.on("tick", function(){

                edges.attr({"x1": function(d){return d.source.x;},
                            "y1": function(d){return d.source.y;},
                            "x2": function(d){return d.target.x;},
                            "y2": function(d){return d.target.y;}
                });

                nodes.attr({"cx":function(d){return d.x;},
                            "cy":function(d){return d.y;}
                });

                nodelabels.attr("x", function(d) { return d.x; })
                          .attr("y", function(d) { return d.y; });

                edgepaths.attr('d', function(d) { var path='M '+d.source.x+' '+d.source.y+' L '+ d.target.x +' '+d.target.y;
                                                   //console.log(d)
                                                   return path});

                edgelabels.attr('transform',function(d,i){
                    if (d.target.x<d.source.x){
                        bbox = this.getBBox();
                        rx = bbox.x+bbox.width/2;
                        ry = bbox.y+bbox.height/2;
                        return 'rotate(180 '+rx+' '+ry+')';
                        }
                    else {
                        return 'rotate(0)';
                        }
                });
            });

            $(svg) = decodeURIComponent(svg);
        </script>
        """

        @js(w, Blink.fill("body", $code))

        # println("function display_blink after Blink.fill")

    # else
    #     #= this is the same as above, with a few differences:
    #     - when we create the div, set some style attributes so the div itself
    #     grows with the display window
    #     - After obtaining the image data, we delete the width and height
    #     properties on the layout so that if the user happened to have set them
    #     on the Julia side, they will be removed -- allowing the plot to always
    #     fill the div
    #     =#
    #     magic = """
    #     <script>
    #     (function() {
    #         var WIDTH_IN_PERCENT_OF_PARENT = 100
    #         var HEIGHT_IN_PERCENT_OF_PARENT = 100;
    #         var gd = Plotly.d3.select('body')
    #             .append('div').attr("id", "$(p.plot.divid)")
    #             .style({
    #                 width: WIDTH_IN_PERCENT_OF_PARENT + '%',
    #                 'margin-left': (100 - WIDTH_IN_PERCENT_OF_PARENT) / 2 + '%',
    #                 height: HEIGHT_IN_PERCENT_OF_PARENT + 'vh',
    #                 'margin-top': (100 - HEIGHT_IN_PERCENT_OF_PARENT) / 2 + 'vh'
    #             })
    #             .node();
    #         var plot_json = $(json(p.plot));
    #         var data = plot_json.data;
    #         var layout = plot_json.layout;
    #         Plotly.newPlot(gd, data, layout).then(function(gd) {
    #                  $(done) = true;
    #                  var img_data = Plotly.toImage(gd, {"format": "svg"});
    #                  delete gd.layout.width
    #                  delete gd.layout.height
    #                  return img_data
    #             }).then(function(img_data) {
    #                 var svg_data = img_data.replace(/^data:image\\/svg\\+xml,/, "");
    #                 $(svg) = decodeURIComponent(svg_data);
    #              });
    #         window.onresize = function() {
    #             Plotly.Plots.resize(gd);
    #             };
    #         }
    #     )();
    #     </script>
    #     """
    #     @js(w, Blink.fill("body", $magic))
    # end

    p.plot
end

## API Methods for ElectronDisplay
# function _img_data(p::ElectronPlot, format::String; show::Bool=false)
#     _formats = ["png", "jpeg", "webp", "svg"]
#     if !(format in _formats)
#         error("Unsupported format $format, must be one of $_formats")
#     end
#
#     opened_here = !isactive(p.view)
#     opened_here && display(p; show=show, resize=false)
#
#     out = @js p.view begin
#         ev = Plotly.Snapshot.toImage(this, d("format"=>$format))
#         @new Promise(resolve -> ev.once("success", resolve))
#     end
#     opened_here && close(p)
#     out
# end
#
# function svg_data(p::ElectronPlot, format="png", robust=false)
#     opened_here = !isactive(p.view)
#     opened_here && (display(p; show=false, resize=false); sleep(0.1))
#
#     out = nothing
#     while out === nothing
#         out = @js p $(svg_var(p))
#         # wait for plot to render
#         sleep(0.2)
#     end
#
#     opened_here && close(p)
#
#     return out
# end

function Blink.js(p::ElectronDisplay, code::JSString; callback=true)
    if !isactive(p)
        return
    end

    Blink.js(get_window(p),
             :(Blink.evalwith(document.getElementById($(string(p.divid))),
                              $(Blink.jsstring(code)))),
             callback=callback)
end

Blink.js(p::ElectronPlot, code::JSString; callback=true) =
    Blink.js(p.view, code; callback=callback)

# Methods from javascript API (docstrings found in api.jl)
# relayout!(p::ElectronDisplay, update::Associative=Dict(); kwargs...) =
#     @js_ p Plotly.relayout(this, $(merge(update, prep_kwargs(kwargs))))
#
# restyle!(p::ElectronDisplay, ind::Int, update::Associative=Dict(); kwargs...) =
#     @js_ p Plotly.restyle(this, $(merge(update, prep_kwargs(kwargs))), $(ind-1))
#
# restyle!(p::ElectronDisplay, inds::AbstractVector{Int}, update::Associative=Dict(); kwargs...) =
#     @js_ p Plotly.restyle(this, $(merge(update, prep_kwargs(kwargs))), $(inds-1))
#
# restyle!(p::ElectronDisplay, update=Dict(); kwargs...) =
#     @js_ p Plotly.restyle(this, $(merge(update, prep_kwargs(kwargs))))
#
# addtraces!(p::ElectronDisplay, traces::AbstractTrace...) =
#     @js_ p Plotly.addTraces(this, $traces)
#
# addtraces!(p::ElectronDisplay, where::Int, traces::AbstractTrace...) =
#     @js_ p Plotly.addTraces(this, $traces, $(where-1))
#
# deletetraces!(p::ElectronDisplay, traces::Int...) =
#     @js_ p Plotly.deleteTraces(this, $(collect(traces)-1))
#
# movetraces!(p::ElectronDisplay, to_end::Int...) =
#     @js_ p Plotly.moveTraces(this, $(collect(to_end)-1))
#
# movetraces!(p::ElectronDisplay, src::AbstractVector{Int}, dest::AbstractVector{Int}) =
#     @js_ p Plotly.moveTraces(this, $(src-1), $(dest-1))
#
# redraw!(p::ElectronDisplay) =
#     @js_ p Plotly.redraw(this)
#
# purge!(p::ElectronDisplay) =
#     @js_ p Plotly.purge(this)
#
# to_image(p::ElectronDisplay; kwargs...) =
#     @js p Plotly.toImage(this, $(Dict(kwargs)))
#
# download_image(p::ElectronDisplay; kwargs...) =
#     @js p Plotly.downloadImage(this, $(Dict(kwargs)))
#
# # unexported (by plotly.js) api methods
# extendtraces!(ed::ElectronDisplay, update::Associative=Dict(),
#               indices::Vector{Int}=[1], maxpoints=-1;) =
#     @js_ ed Plotly.extendTraces(this, $(prep_kwargs(update)), $(indices-1), $maxpoints)
#
# prependtraces!(ed::ElectronDisplay, update::Associative=Dict(),
#                indices::Vector{Int}=[1], maxpoints=-1;) =
#     @js_ ed Plotly.prependTraces(this, $(prep_kwargs(update)), $(indices-1), $maxpoints)