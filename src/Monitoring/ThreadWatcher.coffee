ThreadWatcher =
  init: ->
    return unless Conf['Thread Watcher']
    @shortcut = sc = $.el 'a',
      textContent: 'Watcher'
      id:   'watcher-link'
      href: 'javascript:;'
      className: 'disabled'

    @dialog = UI.dialog 'watcher', 'top: 50px; left: 0px;',
      '<div class=move>Thread Watcher<a class=close href=javascript:;>×</a></div>'

    $.on d, 'QRPostSuccessful',   @cb.post
    $.sync  'WatchedThreads',     @refresh
    $.on sc, 'click', @toggleWatcher
    $.on $('.move>.close', ThreadWatcher.dialog), 'click', @toggleWatcher

    if Conf['Toggleable Thread Watcher']
      Header.addShortcut sc
      $.addClass doc, 'fixed-watcher'

    $.ready ->
      ThreadWatcher.refresh()
      $.add d.body, ThreadWatcher.dialog
      if Conf['Toggleable Thread Watcher']
        ThreadWatcher.dialog.hidden = true

    Thread::callbacks.push
      name: 'Thread Watcher'
      cb:   @node

  node: ->
    favicon = $.el 'a',
      className: 'watch-thread-link'
      href: 'javascript:;'
    $.on favicon, 'click', ThreadWatcher.cb.toggle
    $.before $('input', @OP.nodes.post), favicon
    return if g.VIEW isnt 'thread'
    $.get 'AutoWatch', 0, (item) =>
      return if item['AutoWatch'] isnt @ID
      ThreadWatcher.watch @
      $.delete 'AutoWatch'

  refresh: (watched) ->
    unless watched
      $.get 'WatchedThreads', {}, (item) ->
        ThreadWatcher.refresh item['WatchedThreads']
      return
    nodes = [$('.move', ThreadWatcher.dialog)]
    for board of watched
      for id, props of watched[board]
        x = $.el 'a',
          textContent: '×'
          className: 'close'
          href: 'javascript:;'
        $.on x, 'click', ThreadWatcher.cb.x
        link = $.el 'a', props
        link.title = link.textContent

        div = $.el 'div'
        $.add div, [x, $.tn(' '), link]
        nodes.push div

    $.rmAll ThreadWatcher.dialog
    $.add ThreadWatcher.dialog, nodes

    watched = watched[g.BOARD] or {}
    for ID, thread of g.BOARD.threads
      favicon = $ '.watch-thread-link', thread.OP.nodes.post
      if ID of watched
        $.addClass favicon, 'watched'
      else
        $.rmClass favicon, 'watched'
    return

  toggleWatcher: ->
    $.toggleClass ThreadWatcher.shortcut, 'disabled'
    ThreadWatcher.dialog.hidden = !ThreadWatcher.dialog.hidden

  cb:
    toggle: ->
      ThreadWatcher.toggle Get.postFromNode(@).thread
    x: ->
      thread = @nextElementSibling.pathname.split '/'
      ThreadWatcher.unwatch thread[1], thread[3]
    post: (e) ->
      {board, postID, threadID} = e.detail
      if postID is threadID
        if Conf['Auto Watch']
          $.set 'AutoWatch', threadID
      else if Conf['Auto Watch Reply']
        ThreadWatcher.watch board.threads[threadID]

  toggle: (thread) ->
    unless $.hasClass $('.watch-thread-link', thread.OP.nodes.post), 'watched'
      ThreadWatcher.watch thread
    else
      ThreadWatcher.unwatch thread.board, thread.ID

  unwatch: (board, threadID) ->
    $.get 'WatchedThreads', {}, (item) ->
      watched = item['WatchedThreads']
      delete watched[board][threadID]
      delete watched[board] unless Object.keys(watched[board]).length
      ThreadWatcher.refresh watched
      $.set 'WatchedThreads', watched

  watch: (thread) ->
    $.get 'WatchedThreads', {}, (item) ->
      watched = item['WatchedThreads']
      watched[thread.board] or= {}
      watched[thread.board][thread] =
        href: "/#{thread.board}/res/#{thread}"
        textContent: Get.threadExcerpt thread
      ThreadWatcher.refresh watched
      $.set 'WatchedThreads', watched