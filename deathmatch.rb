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

  def normal
    self.class.new(-@y, @x)
  end

  def dot(other)
    self.x * other.x + self.y * other.y
  end

  def projection(other)
    other.normalise * self.dot(other.normalise)
  end

  def distance(vector)
    Math.sqrt((@x - vector.x) ** 2 + (@y - vector.y) ** 2)
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
      # Line.new(Vector.new(100, 100), Vector.new(200, 200)),

      Line.new(Vector.new(200, 200), Vector.new(200, 400)),
      Line.new(Vector.new(200, 400), Vector.new(400, 400)),

      Line.new(Vector.new(400, 200), Vector.new(550, 200)),
      Line.new(Vector.new(550, 200), Vector.new(550, 350)),
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
    return if player.cooldown?
    r = Rocket.new(player, direction)
    player.fire
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
    check_collisions
    @players.each { |p| p.tick(dt) }
  end

  def check_collisions
    @players.each do |p|
      @rockets.each do |r|
        if r.collide? p
          dir = (r.position - p.position) * -1.0
          p.knocked(dir)
          p.take_damage(r)
          remove_rocket r
        end
      end
    end

    @players.each do |p|
      @walls.each do |w|
        if p.circle.collide?(w)
          p.reflect(w)
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
  attr_reader :position, :dead, :health
  attr_accessor :name

  MAX_SPEED = 300.0
  ACCELRATION = 80.0
  DAMPING = 0.96

  def initialize
    @@n ||= 0
    @dead = false
    @id = (@@n += 1)
    @name = "Player #{@id.to_s}"
    @velocity = Vector.new(rand(50).to_f - 25, rand(50).to_f - 25)
    @cooldown = 0
    @killer_name = ""
    @score = 0
    @consecutive_kills = 0
    @crowned = false
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

  def reflect(wall)
    normal = (wall.b - wall.a).normal
    direction = @velocity.projection(normal) * -2.0
    @velocity += direction
    @position += @velocity * 0.02
  end

  def knocked(direction)
    @velocity += (direction.normalise * 200)
  end

  def crown!
    @crowned = true
  end

  def crowned?
    !!@crowned
  end

  def take_damage(rocket)
    @health -= 10
    die(rocket.owner) if @health <= 0
  end

  def die(killer)
    @dead = true
    @consecutive_kills = 0
    @respawn = 2.to_f
    @killer_name = killer.name
    @score  -= 1
    killer.boost

    if @crowned
      killer.crown!
      @crowned = false
    end
  end

  def boost
    return if @dead
    rem = (100.0 - @health)
    @health += rem / 2.0
    @score  += (@consecutive_kills += 1)
  end

  def circle
    Circle.new(@position, 25)
  end

  def fire
    @cooldown = 5
  end

  def cooldown?
    @cooldown > 0
  end

  def tick(dt)
    if @dead
      if @respawn <= 0
        spawn
      end
      @respawn -= dt
      return
    end

    if @velocity.magnitude > MAX_SPEED
      @velocity = @velocity.normalise * MAX_SPEED
    end
    @velocity *= DAMPING
    @position += @velocity * dt

    @cooldown -= 1
  end

  def to_h(you=nil)
    {
      name: @name,
      you: (self === you),
      pos: {x: @position.x, y: @position.y},
      dead: @dead,
      health: @health,
      respawn: @respawn,
      killer_name: @killer_name,
      score: @score,
      crowned: @crowned,
    }
  end
end

class Rocket
  attr_reader :position, :owner

  ROCKET_SPEED = 600.0

  def initialize(owner, direction)
    @owner = owner
    @position = owner.position + (direction.normalise * 20)
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
    Circle.new(@position, 13)
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
    ac = position - line.a
    ab = line.b   - line.a

    ab2  = ab.dot(ab)
    acab = ac.dot(ab)

    t = acab / ab2

    if t < 0
      t = 0
    elsif t > 1
      t = 1
    end

    h = ((ab * t) + line.a - position)

    h2 = h.dot(h)

    h2 <= radius * radius
  end
end


$world = World.new

dt = 1.0 / 60.0

EventMachine.run do
  world_ticker = proc {
    $world.tick(dt)
    EventMachine::add_timer dt, world_ticker
  }

  world_ticker.call

  EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|

    crowner ||= EventMachine::PeriodicTimer.new(dt*100) do
      if not $world.players.map(&:crowned?).any?
        $world.players.sample.crown!
      end
    end

    player = $world.new_player

    ws.onopen do
      world_sender = proc{
        ws.send $world.to_json(player)
        EventMachine::add_timer 0.00016, world_sender
      }

      world_sender.call
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
        when 'name'
          player.name = command['name']
        end
      end
    end

    ws.onclose do
      $world.remove_player(player)
    end
  end
end
