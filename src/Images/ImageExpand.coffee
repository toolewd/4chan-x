ImageExpand =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Image Expansion']

    @EAI = $.el 'a',
      className: 'expand-all-shortcut'
      textContent: 'EAI'
      title: 'Expand All Images'
      href: 'javascript:;'
    $.on @EAI, 'click', ImageExpand.cb.toggleAll
    Header.addShortcut @EAI

    Post::callbacks.push
      name: 'Image Expansion'
      cb: @node
  node: ->
    return unless @file?.isImage
    {thumb} = @file
    $.on thumb.parentNode, 'click', ImageExpand.cb.toggle
    if @isClone and $.hasClass thumb, 'expanding'
      # If we clone a post where the image is still loading,
      # make it loading in the clone too.
      ImageExpand.contract @
      ImageExpand.expand @
      return
    if ImageExpand.on and !@isHidden
      ImageExpand.expand @
  cb:
    toggle: (e) ->
      return if e.shiftKey or e.altKey or e.ctrlKey or e.metaKey or e.button isnt 0
      e.preventDefault()
      ImageExpand.toggle Get.postFromNode @
    toggleAll: ->
      $.event 'CloseMenu'
      if ImageExpand.on = $.hasClass ImageExpand.EAI, 'expand-all-shortcut'
        ImageExpand.EAI.className = 'contract-all-shortcut'
        ImageExpand.EAI.title     = 'Contract All Images'
        func = ImageExpand.expand
      else
        ImageExpand.EAI.className = 'expand-all-shortcut'
        ImageExpand.EAI.title     = 'Expand All Images'
        func = ImageExpand.contract
      for ID, post of g.posts
        for post in [post].concat post.clones
          {file} = post
          continue unless file and file.isImage and doc.contains post.nodes.root
          if ImageExpand.on and
            (!Conf['Expand spoilers'] and file.isSpoiler or
            Conf['Expand from here'] and file.thumb.getBoundingClientRect().top < 0)
              continue
          $.queueTask func, post
      return
    setFitness: ->
      (if @checked then $.addClass else $.rmClass) doc, @name.toLowerCase().replace /\s+/g, '-'
<% if (type === 'userjs') { %>
# XXX Opera doesn't support CSS vh.
      return unless @name is 'Fit height'
      if @checked
        $.on window, 'resize', ImageExpand.resize
        unless ImageExpand.style
          ImageExpand.style = $.addStyle null
        ImageExpand.resize()
      else
        $.off window, 'resize', ImageExpand.resize
  resize: ->
    ImageExpand.style.textContent = ":root.fit-height .full-image {max-height:#{doc.clientHeight}px}"
<% } %>

  toggle: (post) ->
    {thumb} = post.file
    unless post.file.isExpanded or $.hasClass thumb, 'expanding'
      ImageExpand.expand post
      return
    ImageExpand.contract post
    node = post.nodes.root
    rect = if Conf['Advance on contract'] then do ->
      # FIXME does not work with Quote Threading
      while node.nextElementSibling
        return post.nodes.root unless node = node.nextElementSibling
        continue unless $.hasClass node, 'postContainer'
        break if node.offsetHeight > 0 and not $ '.stub', node
      node.getBoundingClientRect()
    else
      post.nodes.root.getBoundingClientRect()
    return unless rect.top <= 0 or rect.left <= 0

    {top} = rect
    if Conf['Fixed Header'] and not Conf['Bottom Header']
      headRect = Header.bar.getBoundingClientRect()
      top += - headRect.top - headRect.height

    root = <% if (type === 'crx') { %>d.body<% } else { %>doc<% } %>

    root.scrollTop += top if rect.top  < 0
    root.scrollLeft = 0   if rect.left < 0

  contract: (post) ->
    $.rmClass post.nodes.root, 'expanded-image'
    $.rmClass post.file.thumb, 'expanding'
    post.file.isExpanded = false

  expand: (post, src) ->
    # Do not expand images of hidden/filtered replies, or already expanded pictures.
    {thumb} = post.file
    return if post.isHidden or post.file.isExpanded or $.hasClass thumb, 'expanding'
    $.addClass thumb, 'expanding'
    if post.file.fullImage
      # Expand already-loaded/ing picture.
      $.asap (-> post.file.fullImage.naturalHeight), ->
        ImageExpand.completeExpand post
      return
    post.file.fullImage = img = $.el 'img',
      className: 'full-image'
      src: src or post.file.URL
    $.on img, 'error', ImageExpand.error
    $.asap (-> post.file.fullImage.naturalHeight), ->
      ImageExpand.completeExpand post
    $.after thumb, img

  completeExpand: (post) ->
    {thumb} = post.file
    return unless $.hasClass thumb, 'expanding' # contracted before the image loaded
    post.file.isExpanded = true
    unless post.nodes.root.parentNode
      # Image might start/finish loading before the post is inserted.
      # Don't scroll when it's expanded in a QP for example.
      $.addClass post.nodes.root, 'expanded-image'
      $.rmClass  post.file.thumb, 'expanding'
      return
    prev = post.nodes.root.getBoundingClientRect()
    $.queueTask ->
      $.addClass post.nodes.root, 'expanded-image'
      $.rmClass  post.file.thumb, 'expanding'
      return unless prev.top + prev.height <= 0
      root = <% if (type === 'crx') { %>d.body<% } else { %>doc<% } %>
      curr = post.nodes.root.getBoundingClientRect()
      root.scrollTop += curr.height - prev.height + curr.top - prev.top

  error: ->
    post = Get.postFromNode @
    $.rm @
    delete post.file.fullImage
    # Images can error:
    #  - before the image started loading.
    #  - after the image started loading.
    unless $.hasClass(post.file.thumb, 'expanding') or $.hasClass post.nodes.root, 'expanded-image'
      # Don't try to re-expend if it was already contracted.
      return
    ImageExpand.contract post

    src = @src.split '/'
    if src[2] is 'images.4chan.org'
      URL = Redirect.to 'file',
        boardID:  src[3]
        filename: src[5]
      if URL
        setTimeout ImageExpand.expand, 10000, post, URL
        return
      if g.DEAD or post.isDead or post.file.isDead
        return

    timeoutID = setTimeout ImageExpand.expand, 10000, post
    # XXX CORS for images.4chan.org WHEN?
    $.ajax "//api.4chan.org/#{post.board}/res/#{post.thread}.json", onload: ->
      return if @status isnt 200
      for postObj in JSON.parse(@response).posts
        break if postObj.no is post.ID
      if postObj.no isnt post.ID
        clearTimeout timeoutID
        post.kill()
      else if postObj.filedeleted
        clearTimeout timeoutID
        post.kill true

  menu:
    init: ->
      return if g.VIEW is 'catalog' or !Conf['Image Expansion']

      el = $.el 'span',
        textContent: 'Image Expansion'
        className: 'image-expansion-link'

      {createSubEntry} = ImageExpand.menu
      subEntries = []
      for key, conf of Config.imageExpansion
        subEntries.push createSubEntry key, conf

      $.event 'AddMenuEntry',
        type: 'header'
        el: el
        order: 105
        subEntries: subEntries

    createSubEntry: (type, config) ->
      label = $.el 'label',
        innerHTML: "<input type=checkbox name='#{type}'> #{type}"
      input = label.firstElementChild
      if type in ['Fit width', 'Fit height']
        $.on input, 'change', ImageExpand.cb.setFitness
      if config
        label.title   = config[1]
        input.checked = Conf[type]
        $.event 'change', null, input
        $.on input, 'change', $.cb.checked
      el: label

  menuToggle: (e) ->
    ImageExpand.opmenu.toggle e, @, g
