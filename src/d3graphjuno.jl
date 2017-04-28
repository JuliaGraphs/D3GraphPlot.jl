

media(SyncPlot, Media.Plot)
media(Plot, Media.Plot)

Media.render(::Juno.PlotPane, plot::SyncPlot) = display_blink(plot)

@render Juno.PlotPane plot::Plot SyncPlot(plot)