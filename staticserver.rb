class StaticHttpServer < EventMachine::Connection

  include EventMachine::HttpServer

  def process_http_request
    puts "Got a request for #{@http_path_info}"
    path = get_path(@http_path_info)
    # Really stupid server, serve up statics
    return not_authorized unless authorized?(path)

    file_path = File.expand_path("../#{path}", __FILE__)
    puts "Trying to serve #{file_path}"
    return not_found unless File.exist?(file_path)

    return send_response(file_path)
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

  def get_path(path)
    if path == "/"
      return "index.html"
    else
      return path
    end
  end

  def authorized?(path)
    path_filters.each {|f| return false if f.call(path)}

    true
  end

  def path_filters
    [ lambda { |n| n.include?("..") }
    ]
  end

end
