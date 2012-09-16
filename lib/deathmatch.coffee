name = localStorage['name'] || (localStorage['name'] = prompt("Enter name"))

canvas = document.getElementById 'canvas'

# window.addEventListener 'resize', ->
#   canvas.width = document.width
#   canvas.height = document.height

# canvas.width = 800 # document.width
# canvas.height = 600 # document.height

ctx = canvas.getContext '2d'

window.Game = {}

Game.ws = ws = new WebSocket "ws://#{window.location.hostname}:8080"

up = false
down = false
left = false
right = false

crosshair = { x: 0, y: 0 }
window.addEventListener 'mousemove', (event) ->
  crosshair.x = event.clientX - canvas.offsetLeft
  crosshair.y = event.clientY - canvas.offsetTop

keyIgnorer = (event) ->
  if event.keyCode in [37..40]
    event.preventDefault()

window.addEventListener 'keydown', (event) ->
  keyIgnorer(event)
  kc = event.keyCode
  if kc in [87, 38, 75] then up = true
  if kc in [83, 40, 74] then down = true
  if kc in [65, 37, 72] then left = true
  if kc in [68, 39, 76] then right = true

window.addEventListener 'keyup', (event) ->
  keyIgnorer(event)
  kc = event.keyCode
  if kc in [87, 38, 75] then up = false
  if kc in [83, 40, 74] then down = false
  if kc in [65, 37, 72] then left = false
  if kc in [68, 39, 76] then right = false

window.addEventListener 'mousedown', (event) ->
  ws.send(JSON.stringify({
    type: 'shoot',
    x: event.clientX - canvas.offsetLeft,
    y: event.clientY - canvas.offsetTop,
  }))

# F to fullscreen
window.addEventListener 'keydown', (event) ->
  kc = event.keyCode
  if kc == 70 and BigScreen.enabled then BigScreen.toggle()

# setInterval((->
#   keys = []
#   if up then ws.send 'up'
#   if down then ws.send 'down'
#   if left then ws.send 'left'
#   if right then ws.send 'right'
# ), 10)

Game.world = world = {
  players: []
  rockets: []
  walls: []
}

ws.onmessage = (evt) ->
  Game.world = world = JSON.parse(evt.data)

Game.drawCallbacks = []

drawStuff = ->
  keys = []
  if up then keys.push 'up'
  if down then keys.push 'down'
  if left then keys.push 'left'
  if right then keys.push 'right'
  if up || down || left || right
    ws.send JSON.stringify({type: 'move', keys: keys})

  ctx.clearRect 0, 0, canvas.width, canvas.height

  for rocket in world.rockets
    ctx.lineWidth = 1
    ctx.fillStyle = '#330000'
    ctx.strokeStyle = '#000000'
    ctx.beginPath()
    ctx.arc(rocket.pos.x, rocket.pos.y, 5, 0, Math.PI * 2)
    ctx.fill()
    ctx.stroke()

  players = world.players.sort (a,b) ->
    if a.score == b.score
      if a.name >= b.name then 1 else -1
    else
      if a.score < b.score then 1 else -1

  leaderboard_pos = [650, 40]

  for player in players
    ctx.fillStyle = if player.dead then 'rgba(255,255,255,0.2)' else '#FFFFFF'
    ctx.strokeStyle = if player.dead then 'rgba(0,0,0,0.2)' else '#000000'
    ctx.lineWidth = 5
    ctx.beginPath()
    ctx.arc(player.pos.x, player.pos.y, 20, 0, Math.PI * 2)
    ctx.fill()
    ctx.stroke()

    if player.you
      ctx.fillStyle = 'rgb(255,0,0)'
      ctx.strokeStyle = 'rgb(0,0,0)'
    else
      ctx.fillStyle = 'rgb(0,0,255)'
      ctx.strokeStyle = 'rgb(0,0,0)'

    if !player.dead
      health = player.health / 100.0
      rem = 1.0 - health

      startAngle = (rem / 2) * Math.PI * 2
      endAngle = startAngle + (health * Math.PI * 2)

      startAngle -= Math.PI / 2
      endAngle -= Math.PI / 2

      ctx.lineWidth = 2
      ctx.save()
      ctx.beginPath()
      ctx.arc(player.pos.x, player.pos.y, 20, startAngle, endAngle)
      ctx.closePath();
      ctx.clip()
      if window.face
        ctx.drawImage(window.face, player.pos.x - 20, player.pos.y - 20, 40, 40);
      ctx.stroke()
      ctx.restore()

    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.font = '12px Helvetica, Arial, sans-serif'
    ctx.fillStyle = if player.crowned then 'rgba(128,128,0,0.8)' else 'rgba(0,0,0,0.5)'
    ctx.fillText(player.name, player.pos.x, player.pos.y - 30)


    if player.you
      if player.dead
        ctx.textAlign = 'center'
        ctx.font = '32px Helvetica, Arial, sans-serif'
        ctx.fillStyle = 'rgba(0,0,0,0.4)'
        respawn = Math.round(player.respawn * 10) / 10.0
        ctx.fillText("Respawn in #{respawn}", 400, 300)
        ctx.fillStyle = 'rgba(200,0,0,0.4)'
        ctx.fillText("Killed by #{player.killer_name}", 400, 350)

    ctx.textAlign = 'left'
    ctx.font = '12px Helvetica, Arial, sans-serif'
    ctx.fillStyle = if player.you then 'rgba(200,0,0,0.4)'  else 'rgba(0,0,0,0.4)'
    ctx.fillText("#{player.name}:", leaderboard_pos[0], leaderboard_pos[1])
    ctx.textAlign = 'right'
    ctx.fillText("#{player.score}", leaderboard_pos[0]+125, leaderboard_pos[1])
    leaderboard_pos[1] += 20


  for wall in world.walls
    ctx.lineWidth = 8
    ctx.lineCap = "round"
    ctx.strokeStyle = ptrn
    ctx.beginPath()
    ctx.moveTo(wall.a.x - 4, wall.a.y + 4)
    ctx.lineTo(wall.b.x - 4, wall.b.y + 4)
    ctx.stroke()

  ctx.save()
  ctx.globalCompositeOperation = 'destination-out'
  for wall in world.walls
    ctx.strokeStyle = '#000000'
    ctx.beginPath()
    ctx.moveTo(wall.a.x - 0.75, wall.a.y + 0.75)
    ctx.lineTo(wall.b.x - 0.75, wall.b.y + 0.75)
    ctx.stroke()
  ctx.restore()

  for wall in world.walls
    ctx.strokeStyle = '#000000'
    ctx.beginPath()
    ctx.moveTo(wall.a.x, wall.a.y)
    ctx.lineTo(wall.b.x, wall.b.y)
    ctx.stroke()

  ctx.fillStyle = 'rgba(0,160,0,0.6)'
  ctx.beginPath()
  ctx.arc(crosshair.x, crosshair.y, 10, 0, Math.PI * 2)
  ctx.fill()

  for c in Game.drawCallbacks
    c(ctx)

  requestAnimationFrame(drawStuff)

navigator.webkitGetUserMedia {video: true}, (stream) ->
  video = document.createElement('video')
  video.autoplay = true
  video.src = window.webkitURL.createObjectURL(stream)
  cvs = document.createElement('canvas')
  cvs2 = document.createElement('canvas')
  window.face = document.createElement('canvas')
  face.width = 40
  face.height = 40
  cctx = cvs.getContext('2d')
  cctx2 = cvs2.getContext('2d')
  fctx = face.getContext('2d')

  document.body.appendChild(video)
  document.body.appendChild(cvs2)
  document.body.appendChild(cvs)
  document.body.appendChild(face)

  update = ->
    m = 8
    w = cvs2.width = cvs.width = video.videoWidth / m
    h = cvs2.height = cvs.height = video.videoHeight / m
    cctx.drawImage(video, 0, 0, video.videoWidth, video.videoHeight, 0, 0, w, h);
    cctx2.drawImage(video, 0, 0, video.videoWidth, video.videoHeight, 0, 0, w, h);
    detector = ccv.detect_objects({
      "canvas" : ccv.grayscale(ccv.pre(cvs)),
      "cascade" : cascade,
      "interval" : 20,
      "min_neighbors" : 1,
      "async" : true,
      "worker" : 1
    })
    detector((data) ->
      data.forEach((f) ->
        fctx = face.getContext('2d')
        fctx.drawImage(cvs2, f.x-2, f.y, f.width+4, f.height+4, 0, 0, 40, 40)
      )
    )

  setInterval(update, 1000)

# Wall shadow pattern
pattern = new Image()
pattern.src = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAECAYAAAC6Jt6KAAAAOElEQVQImZXNIREAIBREwfUgMBg8NahAAyT9IyD4AeDMMztz0N01rChUzCgUDMgfuIiHZwz7A6cDSCsFyi2rN64AAAAASUVORK5CYII="

ptrn = null
pattern.onload = ->
  ptrn = ctx.createPattern(pattern, 'repeat');

requestAnimationFrame(drawStuff)

ws.onclose = ->
  intervalId = window.setInterval((->
    Game.ws = ws = new WebSocket "ws://#{window.location.hostname}:8080"
    ws.onmessage = (evt) ->
      Game.world = world = JSON.parse(evt.data)
    window.clearInterval(intervalId)
  ), 1000)

ws.onopen = ->
  ws.send(JSON.stringify({
    type: 'name',
    name: name
  }))

