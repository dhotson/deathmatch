require 'em-websocket'
require 'json'

class Vector
  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def +(other)
    self.class.new(@x + other.x, @y + other.y)
  end

  def -(other)
    self.class.new(@x - other.x, @y - other.y)
  end

  def *(n)
    self.class.new(@x * n, @y * n)
  end

  def /(n)
    self.class.new(@x / n, @y / n)
  end

  def magnitude
    (@x ** 2 + @y ** 2) ** 0.5
  end

  def normalise
    self / magnitude
  end
end

class World
  attr_reader :players, :rockets
  def initialize
    @players = []
    @rockets = []
  end

  def new_player
    p = Player.new
    @players.push(p)
    p
  end

  def new_rocket(position, direction)
    r = Rocket.new(position, direction)
    @rockets.push(r)
    r
  end

  def remove_player(player)
    @players.delete(player)
  end

  def tick(dt)
    @rockets.each { |p| p.tick(dt) }
    @players.each { |r| r.tick(dt) }
  end

  def to_h(player=nil)
    {
      players: @players.map { |p| p.to_h(player) },
      rockets: @rockets.map { |r| r.to_h },
    }
  end

  def to_json(player=nil)
    to_h(player).to_json
  end
end

class Player
  attr_reader :name, :position

  def initialize
    @@n ||= 0
    @id = (@@n += 1)
    @name = "Player #{@id.to_s}"
    @position = Vector.new(rand(800).to_f, rand(600).to_f)
    @velocity = Vector.new(rand(50).to_f - 25, rand(50).to_f - 25)
  end

  def move(direction)
    @velocity += direction.normalise * 10.0
  end

  def tick(dt)
    if @velocity.magnitude > 200.0
      @velocity = @velocity.normalise * 200.0
    end
    @velocity *= 0.96
    @position += @velocity * dt
  end

  def to_h(you=nil)
    {
      name: @name,
      you: (self === you),
      pos: {x: @position.x, y: @position.y},
    }
  end
end

class Rocket
  def initialize(owner, direction)
    @owner = owner
    @position = owner.position
    @velocity = direction.normalise * 300.0
  end

  def tick(dt)
    @position += @velocity * dt
  end

  def to_h
    {
      pos: {x: @position.x, y: @position.y},
    }
  end
end

$world = World.new

EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|

  player = $world.new_player

  ws.onopen do
    # ws.send "Welcome!"
  end

  dt = 1.0 / 60.0
  timer = EventMachine::PeriodicTimer.new(dt) do
    $world.tick(dt)
    ws.send $world.to_json(player)
  end

  ws.onmessage do |msg|
    command = JSON.load(msg)

    case command['type']
    when 'move'
      keys = command['keys']
      keys.each do |key|
        dir = ({
          'up' => Vector.new(0, -1),
          'down' => Vector.new(0, 1),
          'left' => Vector.new(-1, 0),
          'right' => Vector.new(1, 0),
        })[key]

        player.move(Vector.new(dir.x, dir.y))
      end
    when 'shoot'
      direction = Vector.new(command['x'], command['y']) - player.position
      $world.new_rocket(player, direction)
    end
  end

  ws.onclose do
    $world.remove_player(player)
  end
end
