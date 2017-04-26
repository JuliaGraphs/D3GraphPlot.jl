{client} = require '../connection'
{views} = require '../ui'

{webview} = views.tags

runafterplot = (runarg) ->
  wb = document.getElementsByTagName('webview')[0]
  wb.executeJavaScript(runarg)

module.exports =
  activate: ->
    client.handle
      plot: (x) => @show x
      plotsize: => @plotSize()
      ploturl: (url) => @ploturl url
      ploturlandrun: (url,runarg) => @ploturlandrun url,runarg
    @create()

  create: ->
    @pane = @ink.PlotPane.fromId 'default'

  open: ->
    @pane.open split: 'right'

  ensureVisible: ->
    return Promise.resolve(@pane) if @pane.currentPane()
    @open()

  show: (view) ->
    @ensureVisible()
    promise = @pane.show views.render view
    return promise

  plotSize: ->
    @ensureVisible().then =>
      view = atom.views.getView @pane
      [view.clientWidth or 400, view.clientHeight or 300]

  ploturl: (url) ->
    @show webview
      class: 'blinkjl',
      src: url,
      style: 'width: 100%; height: 100%'

  ploturlandrun: (url, runarg) ->
    promise = @show webview
      class: 'blinkjl',
      src: url,
      style: 'width: 100%; height: 100%'
    promise.then =>
      @create()
      setTimeout(runafterplot, 5000, runarg)


