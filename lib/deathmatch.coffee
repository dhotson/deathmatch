name = document.cookie || (document.cookie = prompt("Enter name"))

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

Game.ws = ws = new WebSocket "ws://#{window.location.hostname}:8080"

up = false
down = false
left = false
right = false

crosshair = { x: 0, y: 0 }
window.addEventListener 'mousemove', (event) ->
  crosshair.x = event.clientX
  crosshair.y = event.clientY

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

    ctx.fillStyle = if player.dead then 'rgba(255,255,255,0.2)' else '#FFFFFF'
    ctx.strokeStyle = if player.dead then 'rgba(0,0,0,0.2)' else '#000000'
    ctx.lineWidth = 5
    ctx.beginPath()
    ctx.arc(player.pos.x, player.pos.y, 20, 0, Math.PI * 2)
    ctx.fill()
    ctx.stroke()

    if player.you
      ctx.fillStyle = if player.dead then 'rgba(255,0,0, 0.2)' else 'rgb(255,0,0)'
      ctx.strokeStyle = if player.dead then 'rgba(0,0,0, 0.2)' else 'rgb(0,0,0)'
    else
      ctx.fillStyle = if player.dead then 'rgba(0,0,255, 0.2)' else 'rgb(0,0,255)'
      ctx.strokeStyle = if player.dead then 'rgba(0,0,0, 0.2)' else 'rgb(0,0,0)'

    if !player.dead
      health = player.health / 100.0
      rem = 1.0 - health


      startAngle = (rem / 2) * Math.PI * 2
      endAngle = startAngle + (health * Math.PI * 2)

      startAngle -= Math.PI / 2
      endAngle -= Math.PI / 2

      ctx.lineWidth = 2
      ctx.beginPath()
      ctx.arc(player.pos.x, player.pos.y, 20, startAngle, endAngle)
      ctx.fill()
      ctx.stroke()

    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.font = '12px Helvetica, Arial, sans-serif'
    ctx.fillStyle = 'rgba(0,0,0,0.5)'
    ctx.fillText(player.name, player.pos.x, player.pos.y - 30)


    if player.you
      ctx.textAlign = 'center'
      ctx.font = '12px Helvetica, Arial, sans-serif'
      ctx.fillStyle = 'rgba(0,0,0,0.4)'
      ctx.fillText("Score: #{player.score}", 700, 550)
      if player.dead
        ctx.textAlign = 'center'
        ctx.font = '32px Helvetica, Arial, sans-serif'
        ctx.fillStyle = 'rgba(0,0,0,0.4)'
        respawn = Math.round(player.respawn * 10) / 10.0
        ctx.fillText("Respawn in #{respawn}", 400, 300)
        ctx.fillText("Killed by #{player.killer_name}", 400, 350)



  for wall in world.walls
    ctx.lineWidth = 5
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

  webkitRequestAnimationFrame(drawStuff)

webkitRequestAnimationFrame(drawStuff)

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
