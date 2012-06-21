class StaticHttpServer < EventMachine::Connection

  include EventMachine::HttpServer

  attr_reader :routes
  def initialize(*args)
    initialize_routes!
    super(*args)
  end

  def process_http_request
    path = @http_path_info

    return not_found unless routes.include? path

    return send_response(@routes[path])
  end

  def initialize_routes!
    # Default route for index
    @routes = { "/" => "index.html" }
    Dir["{lib,assets,vendor}/**"].each  do |f|
      @routes["/#{f}"] = f
    end
  end

private

  def send_response(file)
    EventMachine::DelegatedHttpResponse.new(self).tap do |res|
      res.status = 200
      res.content = File.open(file).read
      res.send_response
    end
  end

  def not_authorized
    EventMachine::DelegatedHttpResponse.new(self).tap do |res|
      res.status = 403
      res.content = "Not authorized"
      res.send_response
    end
  end

  def not_found
    EventMachine::DelegatedHttpResponse.new(self).tap do |res|
      res.status = 404
      res.content = "Not found"
      res.send_response
    end
  end

  # Helpers

  def authorized?(path)
    path_filters.each {|f| return false if f.call(path)}

    true
  end

  def path_filters
    [ lambda { |n| n.include?("..") }
    ]
  end

end
