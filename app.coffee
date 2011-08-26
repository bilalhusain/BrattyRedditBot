require.paths.unshift '/usr/local/lib/node_modules'

credentials = require './credentials' # {USERNAME: 'herp', PASSWORD: 'derp'}

http = require 'http'
request = require 'request'

class Reddit	
	HOME = 'http://www.reddit.com'

	constructor: ->
		@init()

	init: ->
		@cookieJar = {}
		@loggedIn = false

	login: (username, password, callback) ->
		@init()
		data = "user=#{escape(username)}&passwd=#{escape(password)}"
		request.post {uri: "#{HOME}/api/login", headers: {'content-type': 'application/x-www-form-urlencoded; charset=UTF-8', 'content-length': data.length}, body: data}, (err, response, body) =>
			cookies = response.headers['set-cookie'] or []
			for cookie in cookies
				r = new RegExp("^(.*?)=(.*)$", "g")
				if (m = r.exec(cookie.split(';')[0])) # !null
					@cookieJar[m[1]] = m[2] # overwrite ok
			@loggedIn = true
			callback() if callback

	list: (path, callback) ->
		request.get {uri: "#{HOME}#{path}", headers: {'cookie': @getCookies()}}, (err, response, body) ->
			permalinks = []
			permalinks.push(child.data.permalink) for child in JSON.parse(body).data.children
			callback(permalinks) if callback

	comments: (path, callback) ->
		request.get {uri: "#{HOME}#{path}", headers: {'cookie': @getCookies()}}, (err, response, body) ->
			obj = JSON.parse(body)
			comments = []
			comments.push(child.data.body) for child in obj[1].data.children
			callback(comments) if callback

	postComment: (path, text, callback) ->
		request.get {uri: "#{HOME}#{path}.json", headers: {'cookie': @getCookies()}}, (err, response, body) =>
			obj = JSON.parse(body)
			modhash = obj[0].data.modhash
			name = obj[0].data.children[0].data.name

			data = "thing_id=#{escape(name)}&text=#{escape(text)}&uh=#{escape(modhash)}"
			request.post {uri: "#{HOME}/api/comment", headers: {'content-type': 'application/x-www-form-urlencoded; charset=UTF-8', 'content-length': data.length, 'cookie': @getCookies()}, body: data}, (err, response, body) =>
				callback() if callback

	getCookies: ->
		cookies = []
		for name, value of @cookieJar
			cookies.push(name + '=' + value)
		cookies.join('; ')

botComment = () ->
	r.list '/r/pics/new/.json?sort=new', (permalinks) ->
		choice = Math.floor(Math.random() * permalinks.length)
		r.postComment permalinks[choice], 'supplies!', () ->
			console.log "@ #{new Date()} - commented on #{permalinks[choice]}"
			setTimeout botComment, (10 + Math.random() * 8) * 1000 * 60 # schedule


r = new Reddit
r.login credentials.USERNAME, credentials.PASSWORD, () ->
	botComment() # trigger

