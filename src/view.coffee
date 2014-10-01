class lrs.LRSView extends lrs.LRSObject
	
	@isTouch = document.ontouchstart == null

	isView: true

	@views = {}

	@actionPattern = ///^(.*?):(.*?)\((.*?)\)///

	@parseTemplates: ->
		templateContainer = $('.templates')
		templateContainer.remove()
		templateEls = $(templateContainer.html()).filter('[data-template]')
		@templates = {}

		for template in templateEls
			$template = $(template)
			name = $template.attr('data-template')
			$template.removeAttr('data-template')
			@templates[name] = template.outerHTML

	constructor: (el = null, @options = null, @owner) ->
		if @template and (not el or el.children().length is 0)
			@_loadTemplate()
			if (el)
				classes = el.attr('class')
				if classes then @el.addClass(classes)
				el.replaceWith(@el)
		else
			@el = el

		@customOutlets = {} if not @customOutlets?
		
		@_createViews()
		@_createOutlets()
		@_createActions()

		super(@options)

	initialize: () ->
		@hidden = @el.hasClass('hidden')
		@enabled = !@el.hasClass('disabled')
		
		for name, view of @views
			view.initialize()
		super

	_loadTemplate: ->
		@el = $(LRSView.templates[@template])

	_createViews: ->
		viewEls = @el.find('[data-view] ')
		@views = {}
		#console.log @, viewEls
		for view in viewEls
			$view = $(view)
			if !$view.attr('data-view') then continue
			info = $view.attr('data-view').split(':')
			$view.removeAttr('data-view')
			#console.log info[0] || info[1], viewEls, '1'
			if (info.length == 1)
				@views[info[0]] = new lrs.LRSView($view, null,  @)
			else
				@views[info[1]] = new lrs.LRSView.views[info[0]+'View']($view, {subTemplate: info[2]}, @)

			if info[0] == 'view' then @view = @views[info[0]]
			else if info[1] == 'view' then @view = @views[info[1]]

	_createOutlets: ->
		outletEls = @el.find('[data-outlet]')
		if (@el.attr('data-outlet')) then outletEls.push(@el)

		@outlets = {}

		for outlet in outletEls
			do (outlet) =>
				$outlet = $(outlet)
				#info = $outlet.attr('data-view').split(':')
				#if (info.length == 1)
				#	info.unshift('default')
				#@outlets[info[1]] = {type: info[0], el: $outlet}
				name = $outlet.attr('data-outlet')
				$outlet.removeAttr('data-outlet')
				type = (outlet.tagName || '').toLowerCase()
				if type is 'input' or type is 'textarea'
					$outlet.on 'change', () => @updateOutletFromDom(name)
				@outlets[name] = {type: type, el: $outlet}

				@updateOutletFromDom(name)

		if (@customOutlets)
			outlet.type = 'custom' for name, outlet of @customOutlets
			_.extend(@outlets, @customOutlets)

		@outlets

	_createActions: ->
		els = @el.find('[data-action]')
		if (@el.attr('data-action')) then els.push(@el)

		self = @

		@actions = {}

		for el in els
			$el = $(el)
			actionStrings = $el.attr('data-action').split(';')
			$el.removeAttr('data-action')
			for string in actionStrings
				action = string.match(LRSView.actionPattern)
				action.shift()
				action[2] = action[2].split(',')
				action[2] = [] if action[2][0] == ''

				if !lrs.LRSView.isTouch && (action[0] == 'tap' or action[0] == 'singleTap')
					action[0] = 'click'

				if (!@actions[action[0]])
					@actions[action[0]] = []

				$el.on(action[0], (e) -> self.delegateAction(e, @))
				#console.log 'action', action[0], action[1], action[2]

				@actions[action[0]].push({el: $el, function: action[1], parameters: action[2]})

		@actions

	delegateAction: (e, el = false) =>
		return unless @enabled
		
		actions = @actions[e.type]

		return unless actions

		for action in actions
			continue if el != false && action.el[0] != el
			parameters = []

			for parameter in action.parameters
				if parameter is 'null'
					parameters.push(null)
				else if parameter.charAt(0).match(/['"]/g) and parameter.charAt(0) is parameter.charAt(parameter.length)
					parameters.push(parameter.substring(1, parameter.length - 2))
				else
					parameters.push(@[parameter])

			parameters.push(@, el, e)

			@dispatch(action.function + 'Action', parameters)
			
	dispatch: (func, parameters = null) ->
		
		propagate = true
		
		if @[func] && _.isFunction(@[func])
			propagate = @[func].apply(@, parameters)
			
		if propagate is true and @owner
			@owner.dispatch(func, parameters)

	updateOutletFromDom: (name) ->
		outlet = @outlets[name]
		return if not outlet

		switch outlet.type
			#when 'default'
			when 'custom'
				outlet.get(@el, @[name])
			when 'input', 'textarea'
				if outlet.el.attr('type') is 'checkbox'
					@[name] = outlet.el.prop('checked')
				else
					@[name] = outlet.el.val()
			when 'img'
				@[name] = outlet.el.attr('src')
			else
				@[name] = outlet.el.html()
				#Other el types

	updateDomFromOutlet: (name) ->
		outlet = @outlets[name]
		return if not outlet

		switch outlet.type
			#when 'default'
			when 'custom'
				outlet.set(@el, @[name])
			when 'input', 'textarea'
				if outlet.el.attr('type') is 'checkbox'
					outlet.el.prop('checked', @[name])
				else
					outlet.el.val(@[name])
			when 'img'
				outlet.el.attr('src', @[name])
			else
				outlet.el.html(@[name])

	set: (name, value) ->
		@[name] = value
		@updateDomFromOutlet(name)
		value

	appendTo: (el) ->
		@el.appendTo(el)
		@

	insertBefore: (el) ->
		@el.insertBefore(el)
		@
		
	insertAfter: (el) ->
		@el.insertAfter(el)
		@
		
	remove: ->
		@el.remove()
		@

	addClass: (classes) ->
		@el.addClass(classes)
		@

	removeClass: (classes) ->
		@el.removeClass(classes)
		@

	enable: (recursive = true, updateClass = true)->
		@enabled = true
		@removeClass('disabled') if updateClass
		if recursive is true
			for viewName, view of @views
				view.enable(recursive, updateClass)
		@

	disable: (recursive = true, updateClass = true) ->
		@enabled = false
		@addClass('disabled') if updateClass
		if recursive is true
			for viewName, view of @views
				view.disable(recursive, updateClass)
		@

	show: ->
		@hidden = false
		@enable(true, false)
		@removeClass('hidden')
		@

	hide: ->
		@hidden = true
		@disable(true, false)
		@addClass('hidden')
		@

	hideAction: -> @hide()

class lrs.LRSView.views.LRSListView extends lrs.LRSView

	initialize: (content = null) ->
		@permanentContent = @el.children()
		@permanentViews = _.clone(@views)
		@permanentViewsArray = (view.el[0] for name, view of @permanentViews)
		@setContent(content)
		super()

	setContent: (content) ->
		return if not _.isNull(content) and not _.isArray(content)	
		return if content is null and @content = []
			
		@views = _.clone(@permanentViews)
		@listViews = []
		@el.children().not(@permanentViewsArray).remove()
		
		if content is null
			@content = []
		else
			@content = []
			for object, i in content
				@content.push object
				@_processObject(object, i)
	
	addItem: (item, before = false) ->
		#if before
			#beforeIndex = _.indexOf(@content, item)
			#@content.splice(beforeIndex, 0, item)
		if before is true
			@content.unshift item
			i = 0
		else if before is false
			@content.push item
			i = @content.length - 1
		else
			i = _.indexOf(@content, before)
			@content.splice(i, 0, item)
			
		@_processObject(item, i)
	
	_processObject: (object, i) ->
		#i = _.indexOf(@content, object)
		if (!object.isView)
			if (@options.itemClass)
				view = new @options.itemClass(null, null, @).initialize(object)
			else
				view = new lrs.LRSView.views.LRSGeneratedListItemView(@options.subTemplate, null, @).initialize(object)
		else
			view = object
		
		if i is @listViews.length
			view.appendTo(@el)
		else
			view.el.insertBefore(@listViews[i].el)
		@listViews.splice(i, 0, view)
		@views[_.uniqueId('lvi_')] = view

class lrs.LRSView.views.LRSListItemView extends lrs.LRSView

class lrs.LRSView.views.LRSGeneratedListItemView extends lrs.LRSView.views.LRSListItemView 

	constructor: (template, @options, @owner) ->
		@template = template if template

		super(null, options, @owner)

	initialize: (@object) ->

		for name, outlet of @outlets
			value = @object.get(name)
			if (value) then @set(name, value)

		super(@object)
