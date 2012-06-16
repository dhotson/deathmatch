canvas = document.getElementById 'canvas'

# window.addEventListener 'resize', ->
#   canvas.width = document.width
#   canvas.height = document.height

canvas.width = 800 # document.width
canvas.height = 600 # document.height
canvas.style.backgroundColor = '#EEEEEE'
canvas.style.cursor = 'none'

ctx = canvas.getContext '2d'

window.Game = {}

Game.ws = ws = new WebSocket "ws://10.0.1.142:8080"

up = false
down = false
left = false
right = false

crosshair = { x: 0, y: 0 }
window.addEventListener 'mousemove', (event) ->
  crosshair.x = event.clientX
  crosshair.y = event.clientY


window.addEventListener 'keydown', (event) ->
  if event.keyCode == 87 then up = true
  if event.keyCode == 83 then down = true
  if event.keyCode == 65 then left = true
  if event.keyCode == 68 then right = true

window.addEventListener 'keyup', (event) ->
  if event.keyCode == 87 then up = false
  if event.keyCode == 83 then down = false
  if event.keyCode == 65 then left = false
  if event.keyCode == 68 then right = false

window.addEventListener 'mousedown', (event) ->
  ws.send(JSON.stringify({
    type: 'shoot',
    x: event.clientX,
    y: event.clientY,
  }))

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

  for player in world.players
    if player.you
      ctx.fillStyle = if player.dead then 'rgba(255,0,0, 0.2)' else 'rgb(255,0,0)'
      ctx.strokeStyle = if player.dead then 'rgba(0,0,0, 0.2)' else 'rgb(0,0,0)'
    else
      ctx.fillStyle = if player.dead then 'rgba(0,0,255, 0.2)' else 'rgb(0,0,255)'
      ctx.strokeStyle = if player.dead then 'rgba(0,0,0, 0.2)' else 'rgb(0,0,0)'

    ctx.lineWidth = 5
    ctx.beginPath()
    ctx.arc(player.pos.x, player.pos.y, 20, 0, Math.PI * 2)
    ctx.fill()
    ctx.stroke()

  for wall in world.walls
    ctx.lineWidth = 2
    ctx.strokeStyle = '#00FF00'
    ctx.beginPath()
    ctx.moveTo(wall.a.x, wall.a.y)
    ctx.lineTo(wall.b.x, wall.b.y)
    ctx.stroke()

  ctx.fillStyle = 'rgba(0,0,0,0.2)'
  ctx.beginPath()
  ctx.arc(crosshair.x, crosshair.y, 10, 0, Math.PI * 2)
  ctx.fill()

  for c in Game.drawCallbacks
    c(ctx)

  webkitRequestAnimationFrame(drawStuff)

webkitRequestAnimationFrame(drawStuff)
ws.onclose = ->

ws.onopen = ->

