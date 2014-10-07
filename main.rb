
require './server'
require './assets'
require './helper'
require './es_model'


# need to separate out custom from builtin
require './controllers/auth'
require './controllers/assets'
require './controllers/time_series'
require './controllers/report'
require './controllers/url_rewrite'
require './controllers/session'
require './controllers/redirect'
require './controllers/cache_policy'

require 'logger'

require 'securerandom'

# chain together transforms...

# the app at top level, is a lot like processing old win32 or apple OS message pumps

# Ok aparently ruby blocks can reference their enclosing scope!
# how are we going to pass a reference into into the processing block...

# we can forget if user is logged in



class HTTPLoggingController
  # split this into HTTPRequestLogger and HTTPResponseLogger, to unify
  # the interface

  # just gives us a log more control over log redirection, consolidation 
  # we shouldn't be passing in two loggers to the Applicationm class

  def initialize(log)
    @log = log
  end

  def log_request( x)
    # getpeername, and getsockname are better, but unsupported for sslsocket
    # see -> http://stackoverflow.com/questions/19315361/obtaining-client-address-with-ruby-sslsockets
    # port, ip = Socket.unpack_sockaddr_in(x[:socket].getpeername)

    ip = x[:socket].peeraddr[3]
    @log.info( "request from #{ip} '#{ x[:request] ? x[:request].strip : "nil"  }'" )
    #@log.info( "request_headers #{ x[:request_headers] }" )
    # @log.info( "peer addr: #{ x[:socket].peeraddr } ) "
  end

  def log_response( x)
    #@log.info("response '#{ x[:response].strip }'")
    #@log.info("response_headers #{ x[:response_headers] }")
  end  
end

### i think it might be easier if we just returned if we add the message return 
### code. Then we don't have to distingusish policy controllers from other controllers


######
## IMPORTANT
## OK, important. 
## I think now wer're passing controllers around, it might be a lot easier to structure
## this a bit more dynamically.
## all the actions have the same action interface, so we can just pass them as an ordered list
## of actions to take... 

## we want to separate out the rule rewriters into a class too .
## would be nice if we could pass procs where we don't need state too

## IMPRTANT - we don't need an array, we can aggregate, and then set the sequence
## by hand.
## and combine however we want 

## if the controllers were all dumped in a controllers directory that 
## that would clean up the code a lot.
## SessionManager, RuleRewriter ... etc. 

## for example we have a new general controller we'd just add it to the generalcontroller action
## I think we need separate classes for log_response and log_request
## and that will keep the interface consistent

## we can pass general controllers - as an array. it doesn't matter
## and we can do this as first step, before doing everything.


## or we can organize into groups, and pass the groups in
## eg. logger, rewriters, controllers 

## change name GeneralControllers to preemptiveControllers ? 

class GeneralControllers

  def initialize( controllers ) 
    @controllers = controllers
  end

  def action(x)
    @controllers.each do |controller|
      # avoid if there's already a response
      # could actually be return 
  #    next if x[:response]
      controller.action(x)
    end
  end
end


class Application

  # model here is the event processor.
  # this is not well named at all

  def initialize( log, general_controllers, http_logging_controller )
    @log = log

    @general_controllers = general_controllers

    @http_logging_controller = http_logging_controller

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
    # we don't actually need to log this
    if x[:request].nil?
      return nil
    end

    @general_controllers.action( x)


    # do_cache_control( x)
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

  ## the Request response logger - ought to be factored out of here
  ## as well...
  ## have two methods...

  def log_request( x)
    @http_logging_controller.log_request( x)
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

#   def do_cache_control( x)
#     # this may need to be combined with other resource handling, and egg stuff.
#     # caache constrol should be hanlded externally to this.
#     # max-age=0
# 
#     # it's possible this might vary depending on the user-agent
# 
#     unless x[:response_headers]['Cache-Control']
#       #x[:response_headers]['Cache-Control']= "private"
#       x[:response_headers]['Cache-Control']= "private, max-age=0"
#     end
# 
#     # headers['Cache-Control:']= "private,max-age=100000"
#     # firefox will send 'If-None-Match' nicely. dont have to set cache-control flags
#   end
# 

  # CEP, and ES Event Sourcing model running in javascript. It's actually not too much
  # data, if we have snapshots, running on the server. but then loose the power
  # of customizing locally which is the only reason to run locally.

  # what we're doing with checking for an id update - is very similar to ES.


  # change name ResourceNotFoundPolicy or similar ? 

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

    @http_logging_controller.log_response( x)
  end

end


http_log_file = File.new('log.txt', 'w')
http_log_file.sync = 1
http_log = Logger.new( http_log_file  )
http_log.level = Logger::INFO
#http_log_file = Logger.new(STDOUT)
#http_log.level = Logger::INFO

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


db_params = { 
    :host => '127.0.0.1', 
    :dbname => 'prod', 
    :port => 5432, 
    :user => 'events_ro', 
    :password => 'events_ro' 
}

model_data = []

event_sink = Model::EventSink.new( log, model_data )

event_conn = PG::Connection.open( db_params ) 

event_processor = Model::EventProcessor.new( log, event_conn, event_sink )

assets_content = Assets::FileContent.new( log, "#{Dir.pwd}/assets" )

assets_controller = AssetsController.new( assets_content )

report_conn = PG::Connection.open( db_params ) 

#model_reader = Model::ModelReader.new( log, model_data )

time_series_controller = TimeSeriesController.new( model_data )

auth_controller = AuthController.new()

report_controller = ReportController.new( log, report_conn )

http_logging_controller = HTTPLoggingController.new( http_log)


url_rewrite_controller = URLRewriteController.new()

session_controller = SessionController.new()

redirect_controller = RedirectController.new( log)



general_controllers = GeneralControllers.new( [ 
  redirect_controller, 
  session_controller, 
  url_rewrite_controller, 
  assets_controller, 
  time_series_controller, 
  auth_controller, 
  report_controller ,
  CachePolicyController.new()

] ) 


application = Application.new( log, general_controllers, http_logging_controller )

server = Server::Processor.new(http_log)



server.start_ssl(1443) do |socket|
  application.process_request( socket)
end

server.start(8000) do |socket|
  application.process_request( socket)
end


# MEMOIZATION ought to be a lot simpler, if put them in the same event stream.
# eg. can compute at certain time, or id interval etc.

# id = -1

# start processing at event tip less 2000
id = event_conn.exec_params( "select max(id) - 10000 as max_id from events" )[0]['max_id']

log.warn( "processing historic events from #{id}")
id = event_processor.process_events( id )

log.warn( "waiting for current events at #{id}")
event_processor.process_current_events( id )

# block
server.run()


