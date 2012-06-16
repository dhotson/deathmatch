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

  def to_h
    { x: @x, y: @y }
  end
end

class World
  attr_reader :players, :rockets
  def initialize
    @players = []
    @rockets = []

    @walls = [
      Line.new(Vector.new(10, 10), Vector.new(10, 590)),
      Line.new(Vector.new(10, 590), Vector.new(790, 590)),
      Line.new(Vector.new(10, 10), Vector.new(790, 10)),
      Line.new(Vector.new(790, 10), Vector.new(790, 590)),
      # wall(5, 4, 5, 10),
      # wall(5, 4, 5, 10),
      # wall(5, 4, 5, 10),
      # wall(5, 4, 5, 10),
      # wall(5, 10, 9, 10),
    ]
  end

  def wall(gx, gy, g2x, g2y)
    Line.new(
      Vector.new(32 * gx + 16, 32 * gy + 16),
      Vector.new(32 * g2x + 16, 32 * g2y + 16)
    )
  end

  def new_player
    p = Player.new
    @players.push(p)
    p
  end

  def new_rocket(player, direction)
    r = Rocket.new(player, direction)
    @rockets.push(r)
    r
  end

  def remove_player(player)
    @players.delete(player)
  end

  def remove_rocket(rocket)
    @rockets.delete(rocket)
  end

  def tick(dt)
    @rockets.each do |r|
      if r.position.magnitude > 1000
        remove_rocket(r)
      end

      r.tick(dt)
    end
    @players.each { |p| p.tick(dt) }
    check_collisions
  end

  def check_collisions
    @players.each do |p|
      @rockets.each do |r|
        if r.collide? p
          dir = (r.position - p.position) * -1.0
          p.move(dir)
          p.take_damage
          remove_rocket r
        end
      end
    end

    @players.each do |p|
      @walls.each do |w|
        if p.circle.collide?(w)
          p.reverse
        end
      end
    end

    @rockets.each do |r|
      @walls.each do |w|
        if r.circle.collide?(w)
          remove_rocket(r)
        end
      end
    end

  end

  def to_h(player=nil)
    {
      players: @players.map { |p| p.to_h(player) },
      rockets: @rockets.map { |r| r.to_h },
      walls: @walls.map { |w| w.to_h },
    }
  end

  def to_json(player=nil)
    to_h(player).to_json
  end
end

class Player
  attr_reader :name, :position, :dead, :health

  MAX_SPEED = 200.0
  ACCELRATION = 10.0

  def initialize
    @@n ||= 0
    @dead = false
    @id = (@@n += 1)
    @name = "Player #{@id.to_s}"
    @velocity = Vector.new(rand(50).to_f - 25, rand(50).to_f - 25)
    spawn
  end

  def spawn
    @dead = false
    @health = 100
    @position = Vector.new(rand(700).to_f + 50, rand(500).to_f + 50)
  end

  def move(direction)
    @velocity += direction.normalise * ACCELRATION
  end

  def reverse
    @velocity *= -2.0
    @position += (@velocity * 0.01)
  end

  def take_damage
    @health -= 10
    die if @health <= 0
  end

  def die
    @dead = true
    @countdown = (rand(3) + 1).to_f
  end

  def circle
    Circle.new(@position, 20)
  end


  def tick(dt)
    if @dead
      @countdown -= dt
      if @countdown <= 0
        spawn
      end
      return
    end

    if @velocity.magnitude > MAX_SPEED
      @velocity = @velocity.normalise * MAX_SPEED
    end
    @velocity *= 0.96
    @position += @velocity * dt
  end

  def to_h(you=nil)
    {
      name: @name,
      you: (self === you),
      pos: {x: @position.x, y: @position.y},
      dead: @dead,
      health: @health,
    }
  end
end

class Rocket
  attr_reader :position

  ROCKET_SPEED = 400.0

  def initialize(owner, direction)
    @owner = owner
    @position = owner.position + (direction.normalise * 25)
    @velocity = direction.normalise * ROCKET_SPEED
  end

  def tick(dt)
    @position += @velocity * dt
  end

  def collide?(player)
    return false if player == @owner || player.dead
    return true if (player.position - @position).magnitude < 25
  end

  def circle
    Circle.new(@position, 10)
  end

  def to_h
    {
      pos: {x: @position.x, y: @position.y},
    }
  end
end

class Line < Struct.new(:a, :b)
  def to_h
    { a: a.to_h, b: b.to_h }
  end
end

class Circle < Struct.new(:position, :radius)
  def collide?(line)
    a = line.a - position
    b = line.b - position
    dr = (b - a).magnitude
    d = a.x * b.y - b.x * a.y
    s = ((radius ** 2) * (dr ** 2)) - (d ** 2)

    return false if s < 0
    return true
  end
end


$world = World.new

dt = 1.0 / 60.0

timer = false

EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|

  timer ||= EventMachine::PeriodicTimer.new(dt) do
    $world.tick(dt)
  end

  player = $world.new_player

  ws.onopen do
    EventMachine::PeriodicTimer.new(dt) do
      ws.send $world.to_json(player)
    end
  end


  ws.onmessage do |msg|
    if !player.dead
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
  end

  ws.onclose do
    $world.remove_player(player)
  end
end
