Main =
  init: (items) ->
    # flatten Config into Conf
    # and get saved or default values
    flatten = (parent, obj) ->
      if obj instanceof Array
        Conf[parent] = obj[0]
      else if typeof obj is 'object'
        for key, val of obj
          flatten key, val
      else # string or number
        Conf[parent] = obj
      return
    flatten null, Config
    for db in DataBoards
      Conf[db] = boards: {}
    Conf['selectedArchives'] = {}
    
    $.get Conf, Main.initFeatures

    $.on d, '4chanMainInit', Main.initStyle
    $.asap (-> d.head and $('link[rel="shortcut icon"]', d.head) or d.readyState in ['interactive', 'complete']),
      Main.initStyle

  initFeatures: (items) ->
    Conf = items

    pathname = location.pathname.split '/'
    g.BOARD  = new Board pathname[1]
    return if g.BOARD.ID in ['z', 'fk']
    g.VIEW   =
      switch pathname[2]
        when 'res'
          'thread'
        when 'catalog'
          'catalog'
        else
          'index'
    if g.VIEW is 'thread'
      g.THREADID = +pathname[3]

    switch location.hostname
      when 'api.4chan.org'
        return
      when 'sys.4chan.org'
        Report.init()
        return
      when 'images.4chan.org'
        $.ready ->
          if Conf['404 Redirect'] and d.title is '4chan - 404 Not Found'
            Redirect.init()
            pathname = location.pathname.split '/'
            URL = Redirect.to 'file',
              boardID:  g.BOARD.ID
              filename: pathname[pathname.length - 1]
            location.replace URL if URL
        return

    init = (features) ->
      for name, module of features
        # c.time "#{name} initialization"
        try
          module.init()
        catch err
          Main.handleErrors
            message: "\"#{name}\" initialization crashed."
            error: err
        # finally
        #   c.timeEnd "#{name} initialization"
      return

    # c.time 'All initializations'

    init
      'Polyfill':                 Polyfill
      'Redirect':                 Redirect
      'Header':                   Header
      'Catalog Links':            CatalogLinks
      'Settings':                 Settings
      'Announcement Hiding':      PSAHiding
      'Fourchan thingies':        Fourchan
      'Emoji':                    Emoji
      'Color User IDs':           IDColor
      'Remove Spoilers':          RemoveSpoilers
      'Custom CSS':               CustomCSS
      'Linkify':                  Linkify
      'Resurrect Quotes':         Quotify
      'Filter':                   Filter
      'Thread Hiding Buttons':    ThreadHiding
      'Reply Hiding Buttons':     PostHiding
      'Recursive':                Recursive
      'Strike-through Quotes':    QuoteStrikeThrough
      'Quick Reply':              QR
      'Menu':                     Menu
      'Report Link':              ReportLink
      'Thread Hiding (Menu)':     ThreadHiding.menu
      'Reply Hiding (Menu)':      PostHiding.menu
      'Delete Link':              DeleteLink
      'Filter (Menu)':            Filter.menu
      'Download Link':            DownloadLink
      'Archive Link':             ArchiveLink
      'Quote Inlining':           QuoteInline
      'Quote Previewing':         QuotePreview
      'Quote Backlinks':          QuoteBacklink
      'Mark Quotes of You':       QuoteYou
      'Mark OP Quotes':           QuoteOP
      'Mark Cross-thread Quotes': QuoteCT
      'Anonymize':                Anonymize
      'Time Formatting':          Time
      'Relative Post Dates':      RelativeDates
      'File Info Formatting':     FileInfo
      'Fappe Tyme':               FappeTyme
      'Sauce':                    Sauce
      'Image Expansion':          ImageExpand
      'Image Expansion (Menu)':   ImageExpand.menu
      'Reveal Spoilers':          RevealSpoilers
      'Image Loading':            ImageLoader
      'Image Hover':              ImageHover
      'Comment Expansion':        ExpandComment
      'Thread Expansion':         ExpandThread
      'Thread Excerpt':           ThreadExcerpt
      'Favicon':                  Favicon
      'Unread':                   Unread
      'Quote Threading':          QuoteThreading
      'Thread Stats':             ThreadStats
      'Thread Updater':           ThreadUpdater
      'Thread Watcher':           ThreadWatcher
      'Index Navigation':         Nav
      'Keybinds':                 Keybinds

    # c.timeEnd 'All initializations'

    $.on d, 'AddCallback', Main.addCallback
    $.ready Main.initReady

  initStyle: ->
    $.off d, '4chanMainInit', Main.initStyle
    return if !Main.isThisPageLegit() or $.hasClass doc, 'fourchan-x'
    # disable the mobile layout
    $('link[href*=mobile]', d.head)?.disabled = true
    <% if (type === 'crx') { %>
    $.addClass doc, 'webkit'
    $.addClass doc, 'blink'
    <% } else if (type === 'userjs') { %>
    $.addClass doc, 'presto'
    <% } else { %>
    $.addClass doc, 'gecko'
    <% } %>
    $.addClass doc, 'fourchan-x'
    $.addClass doc, g.VIEW
    $.addStyle Main.css

    if g.VIEW is 'catalog'
      $.addClass doc, $.id('base-css').href.match(/catalog_(\w+)/)[1].replace('_new', '').replace /_+/g, '-'
      return

    style          = 'yotsuba-b'
    mainStyleSheet = $ 'link[title=switch]', d.head
    styleSheets    = $$ 'link[rel="alternate stylesheet"]', d.head
    setStyle = ->
      $.rmClass doc, style
      for styleSheet in styleSheets
        if styleSheet.href is mainStyleSheet.href
          style = styleSheet.title.toLowerCase().replace('new', '').trim().replace /\s+/g, '-'
          break
      $.addClass doc, style
    setStyle()
    return unless mainStyleSheet
    if window.MutationObserver
      observer = new MutationObserver setStyle
      observer.observe mainStyleSheet,
        attributes: true
        attributeFilter: ['href']
    else
      $.on mainStyleSheet, 'DOMAttrModified', setStyle

  initReady: ->
    if d.title is '4chan - 404 Not Found'
      if Conf['404 Redirect'] and g.VIEW is 'thread'
        href = Redirect.to 'thread',
          boardID:  g.BOARD.ID
          threadID: g.THREADID
          postID:   +location.hash.match /\d+/ # post number or 0
        location.replace href or "/#{g.BOARD}/"
      return

    unless $.hasClass doc, 'fourchan-x'
      # Something might have gone wrong!
      Main.initStyle()

    if board = $ '.board'
      threads = []
      posts   = []

      for boardChild in board.children
        continue unless $.hasClass boardChild, 'thread'
        thread = new Thread boardChild.id[1..], g.BOARD
        threads.push thread
        for threadChild in boardChild.children
          continue unless $.hasClass threadChild, 'postContainer'
          try
            posts.push new Post threadChild, thread, g.BOARD
          catch err
            # Skip posts that we failed to parse.
            unless errors
              errors = []
            errors.push
              message: "Parsing of Post No.#{threadChild.id.match(/\d+/)} failed. Post will be skipped."
              error: err
      Main.handleErrors errors if errors

      Main.callbackNodes Thread, threads
      Main.callbackNodesDB Post, posts, ->
        $.event '4chanXInitFinished'
        <% if (type !== 'crx') { %>
        Main.checkUpdate()
        <% } %>

      if styleSelector = $.id 'styleSelector'
        passLink = $.el 'a',
          textContent: '4chan Pass'
          href: 'javascript:;'
        $.on passLink, 'click', ->
          window.open '//sys.4chan.org/auth',
            'This will steal your data.'
            'left=0,top=0,width=500,height=255,toolbar=0,resizable=0'
        $.before styleSelector.previousSibling, [$.tn '['; passLink, $.tn ']\u00A0\u00A0']

      return

    try
      localStorage.getItem '4chan-settings'
    catch err
      new Notification 'warning', 'Cookies need to be enabled on 4chan for <%= meta.name %> to properly function.', 30

    $.event '4chanXInitFinished'
    <% if (type !== 'crx') { %>
    Main.checkUpdate()
    <% } %>

  callbackNodes: (klass, nodes) ->
    # get the nodes' length only once
    len = nodes.length
    for callback in klass::callbacks
      # c.profile callback.name
      i = 0
      while i < len
        node = nodes[i++]
        try
          callback.cb.call node
        catch err
          unless errors
            errors = []
          errors.push
            message: "\"#{callback.name}\" crashed on #{klass.name} No.#{node} (/#{node.board}/)."
            error: err
      # c.profileEnd callback.name
    Main.handleErrors errors if errors

  callbackNodesDB: (klass, nodes, cb) ->
    queue = []
    softTask =  ->
      task = queue.shift()
      func = task[0]
      args = Array::slice.call task, 1
      func.apply func, args
      return unless queue.length
      if (queue.length % 7) is 0
        setTimeout softTask, 0
      else
        softTask()

    # get the nodes' length only once
    len    = nodes.length
    i      = 0
    errors = null

    func = (node, i) ->
      for callback in klass::callbacks
        try
          callback.cb.call node
        catch err
          unless errors
            errors = []
          errors.push
            message: "\"#{callback.name}\" crashed on #{klass.name} No.#{node} (/#{node.board}/)."
            error: err
      # finish
      if i is len
        Main.handleErrors errors if errors
        cb() if cb

    while i < len
      node = nodes[i]
      queue.push [func, node, ++i]

    softTask()

  addCallback: (e) ->
    obj = e.detail
    unless typeof obj.callback.name is 'string'
      throw new Error "Invalid callback name: #{obj.callback.name}"
    switch obj.type
      when 'Post'
        Klass = Post
      when 'Thread'
        Klass = Thread
      else
        return
    obj.callback.isAddon = true
    Klass::callbacks.push obj.callback

  <% if (type !== 'crx') { %>
  message: (e) ->
    {version} = e.data
    if version and version isnt g.VERSION
        el = $.el 'span',
          innerHTML: "Update: <%= meta.name %> v#{version} is out, get it <a href=<%= meta.page %> target=_blank>here</a>."
        new Notification 'info', el, 120

  checkUpdate: ->
    return unless Conf['Check for Updates'] and Main.isThisPageLegit()
    now  = Date.now()
    $.get 'lastchecked', 0, ({lastchecked}) ->
      if (lastchecked > now - $.DAY)
        return
      $.ready ->
        $.on window, 'message', Main.message
        $.set 'lastchecked', now
        $.add d.head, $.el 'script',
          src: '<%= meta.repo %>raw/<%= meta.mainBranch %>/latest.js'
  <% } %>

  handleErrors: (errors) ->
    unless errors instanceof Array
      error = errors
    else if errors.length is 1
      error = errors[0]
    if error
      new Notification 'error', Main.parseError(error), 15
      return

    div = $.el 'div',
      innerHTML: "#{errors.length} errors occurred. [<a href=javascript:;>show</a>]"
    $.on div.lastElementChild, 'click', ->
      [@textContent, logs.hidden] = if @textContent is 'show'
        ['hide', false]
      else
        ['show', true]

    logs = $.el 'div',
      hidden: true
    for error in errors
      $.add logs, Main.parseError error

    new Notification 'error', [div, logs], 30

  parseError: (data) ->
    Main.logError data
    message = $.el 'div',
      textContent: data.message
    error = $.el 'div',
      textContent: data.error
    [message, error]

  errors: []
  logError: (data) ->
    c.error data.message, data.error.stack
    Main.errors.push data

  isThisPageLegit: ->
    # 404 error page or similar.
    unless 'thisPageIsLegit' of Main
      Main.thisPageIsLegit = location.hostname is 'boards.4chan.org' and
        !$('link[href*="favicon-status.ico"]', d.head) and
        d.title not in ['4chan - Temporarily Offline', '4chan - Error']
    Main.thisPageIsLegit

  css: """
  <%= grunt.file.read('src/General/css/style.css') %>
  <%= grunt.file.read('src/General/css/yotsuba.css') %>
  <%= grunt.file.read('src/General/css/yotsuba-b.css') %>
  <%= grunt.file.read('src/General/css/futaba.css') %>
  <%= grunt.file.read('src/General/css/burichan.css') %>
  <%= grunt.file.read('src/General/css/tomorrow.css') %>
  <%= grunt.file.read('src/General/css/photon.css') %>
  """

Main.init()
