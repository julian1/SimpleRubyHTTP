
require './server'
require './assets'
require './helper'
require './es_model'
require 'logger'

require 'securerandom'

# chain together transforms...

# the app at top level, is a lot like processing old win32 or apple OS message pumps

# Ok aparently ruby blocks can reference their enclosing scope!
# how are we going to pass a reference into into the processing block...

# we can forget if user is logged in

class AuthController

  def initialize()
    @secret = 'pineapple123'
  end


  def serve_response( x)
    x[:body] = StringIO.new( <<-EOF
        { "authenticated": #{ 
          x[:session][:authenticated] \
          && x[:session][:authenticated] == true \
          ? "true" : "false" 
        } }
      EOF
      )
      x[:response] = "HTTP/1.1 200 OK"
      x[:response_headers]['Content-Type'] = "text/plain"
  end

  def action( x)

    puts "WHOOT here"

    # two methods test whether authenticated and login
    # these things are controllers - they ought to be classes

    # should explicitly test for port 1443 again

    matches = /^GET \/authenticated.json$/.match( x[:request])
    if matches
      serve_response( x)
    end

    matches = /^GET \/login.json\?field1=(.*)$/.match( x[:request])
    if matches and matches.captures.length == 1

      query = URI.decode( matches.captures[0].gsub(/\+/,' ') )
      if( query == @secret)
        x[:session][:authenticated] = true
      end
      serve_response( x)
    end


  end

end


class Application

  # model here is the event processor.
  # this is not well named at all

  def initialize( log, model, assets_content, report_conn, auth_controller )
    @log = log
    @model = model
    @assets_content = assets_content
    # the report conn ought to be encapsulated and delegated to
    @report_conn = report_conn
    @auth_controller = auth_controller

    @sessions = { }

    @log.warn("Application started")
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

    # this kind of chaining could be done more dynamically,
    # using classes and exposing the request match predicates as methods etc.
    # but this is ok,
    # also can delegate, from general controllers, to session controllers etc.
    decode_request( x)
    log_request( x)

    # no request, indicating connection close by remote
    if x[:request].nil?
      return nil
    end

    redirect_to_https( x)
    establish_session( x)
    #handle_post_request( x)
    strip_http_version( x)
    rewrite_index_get( x)
    # could group all these together and delegate
    serve_asset( x, @assets_content )
    serve_model_resource( x, @model )
    serve_authentification( x)
    serve_report_resource( x, @report_conn )
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
    # getpeername, and getsockname are better, but unsupported for sslsocket
    # see -> http://stackoverflow.com/questions/19315361/obtaining-client-address-with-ruby-sslsockets
    # port, ip = Socket.unpack_sockaddr_in(x[:socket].getpeername)

    ip = x[:socket].peeraddr[3]
    @log.info( "request from #{ip} '#{ x[:request] ? x[:request].strip : "nil"  }'" )
    @log.info( "request_headers #{ x[:request_headers] }" )
    # puts "peer addr: #{ x[:socket].peeraddr } "
  end


  def redirect_to_https( x)

    # We should read the host from the Host flag - no that would
    # be insecure

    port = x[:socket].addr[1]
    if port == 8000
      @log.info( "redirect to https" )
      x[:response] = "HTTP/1.1 302 Found"
      x[:response_headers]['Location'] = "https://localhost:1443"
    end
  end


  def establish_session( x)
    # there's a bit of a bug, in which if we change the attributes,
    # and get multiple sessions, the cookie header gets overwritten
    # by the multiple returned cookies.

    # IMPORTANT - We need, to change this to use Secure flag, then only send it
    # when the connection is https

    sent_cookie = x[:request_headers]['Cookie']
    session_id = -1
    begin
      id, session_id = sent_cookie.split('=')
    rescue
      session_id = SecureRandom.uuid
      new_cookie = "id=#{ session_id }; path=/"
      x[:response_headers]['Set-Cookie'] = new_cookie
    end

    puts "session_id is #{session_id}"

    # create new session
    @sessions[session_id] = {} if @sessions[session_id].nil?
    x[:session] = @sessions[session_id]

    puts "session data is #{x[:session] }"
  end

#
#   def handle_post_request( x)
#     return if x[:response]
#     # should we inject the socket straight in here ?
#     # it makes instantiating the graph harder...
#     if /^POST .*$/.match(x[:request])
#
#       @log.warn("Got post ")
#       # we must read content , otherwise it gets muddled up
#       # it gets read at the next http x[:request], when connection
#       # is keep alive.
#       # abort()
#     end
#   end
#
  def strip_http_version( x)
    return if x[:response]
    # eases subsequent matching
    # - think we should do this before the post, and not care
    # irrespective of the actual http verb
    matches = /^(GET .*)\s(HTTP.*)/.match(x[:request])
    if matches and matches.captures.length == 2
      x[:request] = matches.captures[0]
    end
  end

  def rewrite_index_get( x)
    return if x[:response]
    # rewrite top level / to index.html
    if matches = /^GET \/$/.match(x[:request])
      x[:request] = "GET /index.html"
    end
  end

  def serve_asset( x, assets_content)
    return if x[:response]

    matches = /^GET (.*\.txt|.*\.html|.*\.css|.*\.js|.*\.jpeg|.*\.png|.*\.ico)$/.match(x[:request])
    if matches && matches.captures.length == 1

      digest = assets_content.digest_file( x )
      if_none_match = x[:request_headers]['If-None-Match']

      if digest && if_none_match && if_none_match == digest
        x[:response] = "HTTP/1.1 304 Not Modified"
      else
        # eg. serve normal 200 OK
        assets_content.serve_file( x )
        x[:response_headers]['ETag'] = digest
      end
    end
  end

  def serve_model_resource( x, model )
    return if x[:response]
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


  def serve_authentification( x) 
    return if x[:response] # eg. if not ssl 

    @auth_controller.action( x) 

  end


  def serve_report_resource( x, report_conn )
    return if x[:response]
    # can have separate filters or handle together etc


    matches = /^GET \/report.json\?field1=(.*)$/.match( x[:request])
    if matches and matches.captures.length == 1

      if x[:session][:authenticated] \
        && x[:session][:authenticated] == true

        # so we replace the + with space and then decode
        query = URI.decode( matches.captures[0].gsub(/\+/,' ') )

        @log.info( "got report query '#{query}'")

        # we should return json, or decode the json
        res = report_conn.exec_params( query )
        w = StringIO.new()
        res.each do |row|
            w.puts row
        end
        #   @log.info( "result is #{ w.string } ")
        x[:response] = "HTTP/1.1 200 OK"
        x[:response_headers]['Content-Type'] = "text/plain"
        x[:body] = StringIO.new( w.string )  # we shouldn't need this double handling
      else
        x[:response] = "HTTP/1.1 200 OK"
        x[:response_headers]['Content-Type'] = "text/plain"
        x[:body] = StringIO.new( "Please login first!!" )
      end
    end
  end

  # We have a problem that something's eating exceptions


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
    # note that we could pass in the socket here from application,
    # rather than keeping it around in x.

    Helper.write_response( x )

    x[:session][:last_access] = Time.now

    begin
      x[:session][:page_count] += 1
    rescue
      x[:session][:page_count] = 0
    end

  end

  def log_response( x)
    @log.info("response '#{ x[:response].strip }'")
    @log.info("response_headers #{ x[:response_headers] }")
  end

end


http_log_file = File.new('log.txt', 'a')
http_log_file.sync = 1
http_log = Logger.new( http_log_file  )
http_log.level = Logger::INFO


http_log_file = Logger.new(STDOUT)
http_log.level = Logger::INFO

# we can separate out http requests from everything else by
# just creating two loggers
log = Logger.new(STDOUT)
#log.level = Logger::WARN
log.level = Logger::INFO

myformatter = proc do |severity, datetime, progname, msg|
  "#{severity}: #{datetime}: #{msg}\n"
end

log.formatter = myformatter
http_log.formatter = myformatter

# Ok, we want to show the total amount on the buy and sell side,
# because it's so important. and to compare to other exchanges.

# remember could be fictitious. but should be representative.
# we can see how it changes over time (bollinger), to guague
# if it's following the price, or supportive/resistive.

# we could also do analysis - for example how long the order
# has existed, indicating permanence,

# it's interesting, to know why it's moving up (winklevoss)
# or down (miners requiring settlement), we would have to find
# out the reason of every gid in the list.

# we really need, a non-increasing graph as well. of the orderbook
# as well

# we need to change the db, so the model presenter reader only connects on
# a read only connection.

model_data = []

event_sink = Model::EventSink.new( log, model_data )

event_conn = PG::Connection.open(:dbname => 'prod', :user => 'meteo', :password => 'meteo' )

event_processor = Model::EventProcessor.new( log, event_conn, event_sink )

assets_content = Assets::FileContent.new( log, "#{Dir.pwd}/assets" )

report_conn = PG::Connection.open(:dbname => 'prod', :user => 'meteo', :password => 'meteo' )

model_reader = Model::ModelReader.new( log, model_data )

auth_controller = AuthController.new()

application = Application.new( http_log, model_reader, assets_content, report_conn, auth_controller )

server = Server::Processor.new(http_log)



server.start_ssl(1443) do |socket|
  application.process_request( socket)
end

server.start(8000) do |socket|
  application.process_request( socket)
end


# id = -1

# start processing at event tip less 2000
id = event_conn.exec_params( "select max(id) - 2000 as max_id from events" )[0]['max_id']

log.warn( "processing historic events from #{id}")
id = event_processor.process_events( id )

log.warn( "waiting for current events at #{id}")
event_processor.process_current_events( id )

# block
server.run()


