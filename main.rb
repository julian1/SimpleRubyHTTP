
require './server'
require './static'
require './helper'
require './es_model'


# chain together transforms...


# Ok aparently ruby blocks can reference their enclosing scope!
# how are we going to pass a reference into into the processing block...


class Application

  # model here is the event processor.
  # this is not well named at all

  def initialize( model, file_content, report_conn )
    @model = model
    @file_content = file_content
    # the report conn ought to be encapsulated and delegated to
    @report_conn = report_conn
  end

  def process_request( socket)

    # we can still use functions t
    x = {
      :request => nil,
      :request_headers => {},
      :socket => socket,
      :response => nil,
      :response_headers => {},
      :body => nil
    }

    # this kind of chaining could be done more
    # dynamically, by processing an array
    # and that would support insertAfterFilter() etc.
    # but this is ok,
    decode_request( x)
    log_request( x)

    # no request, indicating connection close by remote
    if x[:request].nil?
      return nil
    end

    handle_post_request( x)
    strip_http_version( x)
    rewrite_index_get( x)
    serve_asset( x, @file_content )
    serve_model_resource( x, @model )
    serve_report_resource( x, @report_conn )
    do_cookie_stuff( x)
    do_cache_control( x)
    catch_all( x)
    send_response( x )
    log_response( x)
    true

  end


  def decode_request( x)
    socket = x[:socket]
    x[:request] = socket.gets
    while line = socket.gets("\r\n")
      break if line == "\r\n"
      s = line.split(':')
      x[:request_headers][ s[0].strip] = s[1].strip
    end
  end

  def log_request( x)

    puts "---------------"
    puts "request '#{ x[:request] ? x[:request].strip : "nil"  }'"
    puts "request_headers #{ x[:request_headers] }"
  end

  def handle_post_request( x)
    # should we inject the socket straight in here ?
    # it makes instantiating the graph harder...
    if /^POST .*$/.match(x[:request])
      puts "************ got post !!! ***********"
      puts m

      # we must read content , otherwise it gets muddled up
      # it gets read at the next http x[:request], when connection
      # is keep alive.
      # abort()
    end
  end

  def strip_http_version( x)
    # eases subsequent matching
    # should do this on other types also ?
    matches = /^(GET .*)\s(HTTP.*)/.match(x[:request])
    if matches and matches.captures.length == 2
      x[:request] = matches.captures[0]
    end
  end

  def rewrite_index_get( x)
    # rewrite top level / to index.html
    if matches = /^GET \/$/.match(x[:request])
      x[:request] = "GET /index.html"
    end
  end

  def serve_asset( x, file_content)

    matches = /^GET (.*\.txt|.*\.html|.*\.css|.*\.js|.*\.jpeg|.*\.png|.*\.ico)$/.match(x[:request])
    if matches && matches.captures.length == 1

      digest = file_content.digest_file( x )
      if_none_match = x[:request_headers]['If-None-Match']

      if digest && if_none_match && if_none_match == digest
        x[:response] = "HTTP/1.1 304 Not Modified"
      else
        # eg. serve normal 200 OK
        file_content.serve_file( x )
        x[:response_headers]['ETag'] = digest
      end
    end
  end

  def serve_model_resource( x, model )
    # can have separate filters or handle together etc

    if /^GET \/get_series.json$/.match(x[:request])
      model.get_series( x)
    end

    # this whole id thing, where client submits id to check for change, is
    # almost equivalent to etag approach
    if /^GET \/get_id.json$/.match(x[:request])
      model.get_id( x )
    end

  end

  def serve_report_resource( x, report_conn )
    # can have separate filters or handle together etc
    #puts "***1***************** got request #{x[:request]} "

    matches = /^GET \/report.json\?field1=(.*)$/.match( x[:request])
    if matches and matches.captures.length == 1

      # so we replace the + with space and then decode
      query = URI.decode( matches.captures[0].gsub(/\+/,' ') )

      puts "********************* got report! #{query} "

      # how do we print up the response ...
      res = report_conn.exec_params( query )
      w = StringIO.new()
      res.each do |row|
          w.puts row
      end
  #    puts "result is #{ w.string } "
      x[:response] = "HTTP/1.1 200 OK"
      x[:response_headers]['Content-Type'] = "text/plain"
      x[:body] = StringIO.new( w.string )  # we shouldn't need this double handling
    end
  end


  def do_cookie_stuff( x)
    # change name - session management
    begin
      cookie = x[:request_headers]['Cookie'].to_i + 1
    rescue
      cookie = 0
    end

    x[:response_headers]['Set-Cookie'] = "#{cookie}"
  end

  def do_cache_control( x)
    # this may need to be combined with other resource handling, and egg stuff.
    # caache constrol should be hanlded externally to this.
    # max-age=0

    # it's possible this might vary depending on the user-agent

    unless x[:response_headers]['Cache-Control']
      #x[:response_headers]['Cache-Control']= "private"
      x[:response_headers]['Cache-Control']= "private, max-age=0"
    end

    # headers['Cache-Control:']= "private,max-age=100000"
    # firefox will send 'If-None-Match' nicely. dont have to set cache-control flags
  end


  # CEP, and ES Event Sourcing model running in javascript. It's actually not too much
  # data, if we have snapshots, running on the server. but then loose the power
  # of customizing locally which is the only reason to run locally.

  # what we're doing with checking for an id update - is very similar to ES.


  def catch_all( x)

    # resource not found
    if x[:response].nil?

      if /^GET.*$/.match(x[:request])
        # GET request
        x[:response] = "HTTP/1.1 404 Not Found"
        x[:response_headers]['Content-Type'] = "text/plain"
        x[:body] = StringIO.new( <<-EOF
  File not found!
          EOF
          )
      else
        # catch all, for non-implemented or badly formed request
        x[:response] = "HTTP/1.1 400 Bad Request"
        x[:response_headers]['Content-Type'] = "text/plain"
        x[:body] = StringIO.new( <<-EOF
  Your browser sent a request that this server could not understand
          EOF
          )
      end
    end
  end

  def send_response( x)
    # note that we could pass in the socket here,
    # rather than pass it about everywhere....
    # issue is that if it's a post, then we want to read ...
    # send response expects this ...

    # we can have a few options about how we send the response.
    # send chunked, etc.
    # either separate methods, or something else ...

    Helper.write_response( x )
  end

  def log_response( x)
    puts "response '#{ x[:response].strip }'"
    puts "response_headers #{ x[:response_headers] }"
  end

end


model_data = []

event_sink = Model::EventSink.new( model_data )

event_conn = PG::Connection.open(:dbname => 'prod', :user => 'meteo', :password => 'meteo' )

event_processor = Model::EventProcessor.new( event_conn, event_sink )

file_content = Static::FileContent.new( "#{Dir.pwd}/static" )

report_conn = PG::Connection.open(:dbname => 'prod', :user => 'meteo', :password => 'meteo' )

model_reader = Model::ModelReader.new( model_data )

application = Application.new( model_reader, file_content, report_conn )

server = Server::Processor.new()


server.start_ssl(1443) do |socket|
  application.process_request( socket)
end

server.start(8000) do |socket|
  application.process_request( socket)
end


# id = -1

# start processing at event tip less 2000
id = event_conn.exec_params( "select max(id) - 2000 as max_id from events" )[0]['max_id']

puts "starting processing events at #{id}"
id = event_processor.process_events( id )

puts "starting processing current events #{id}"
event_processor.process_current_events( id )

# block
server.run()


