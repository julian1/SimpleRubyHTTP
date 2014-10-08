
require './support/server'
require './support/assets'


require './domain/es_model'
require './domain/btcmarkets'
require './domain/bitstamp'


# TODO needs to be more organised
require './controllers/log_request'
require './controllers/auth'
require './controllers/assets'
require './controllers/time_series'
require './controllers/report'
require './controllers/url_rewrite'
require './controllers/session'
require './controllers/redirect'
require './controllers/cache_policy'
require './controllers/not_found'
require './controllers/send_response'
require './controllers/log_response'

require 'logger'
require 'securerandom'


# rather than passing the sole x structure, we could separate out the request and response
# arguments. the issue is other stuff eg. session, and socket. 

# or we could do this for controller interfaces that only need this - eg. by introspection. 
# call a method only if it exists...


# the app at top level, is a lot like processing old win32 or apple OS message pumps

# Ok aparently ruby blocks can reference their enclosing scope!
# how are we going to pass a reference into into the processing block...

# CEP, and ES Event Sourcing model running in javascript - because it can be shipped
# to the server/data.  

# MEMOIZATION ought to be a lot simpler, if put them in the same event stream.
# eg. can compute at certain time, or id interval etc.

# what we're doing with checking for an id update - is very similar to ES.



class Application

  def initialize( log, controllers )
    @log = log
    @controllers = controllers
    @log.warn("Application started")
  end

  def process_request( socket)

    # init message structure
    x = {
      :request => nil,
      :request_headers => {},
      :socket => socket,
      :response => nil,
      :response_headers => {},
      :body => nil
    }

    decode_request( x)

    # note, we aren't logging nil which generally is close

    # no request, indicating connection close by remote
    # we don't actually need to log this
    if x[:request].nil?
      return nil
    end

    @controllers.each do |controller|
      controller.action(x)
    end

    true
  end


  def decode_request( x)
    # TODO needs to separate multiple returned cookies into an array
    socket = x[:socket]
    x[:request] = socket.gets
    while line = socket.gets("\r\n")
      break if line == "\r\n"
      s = line.split(':')
      x[:request_headers][ s[0].strip] = s[1].strip
    end
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


db_params = { 
  :host => '127.0.0.1', 
  :dbname => 'prod', 
  :port => 5432, 
  :user => 'events_ro', 
  :password => 'events_ro' 
}

model_data = { } 

sinks = [
    # ESModel::BitstampModel.new( model_data ),
    BitstampModel.new( model_data ),
    BTCMarketsModel.new( model_data)
]

event_sink = Model::EventSink.new( sinks )

event_conn = PG::Connection.open( db_params ) 

event_processor = Model::EventProcessor.new( log, event_conn, event_sink )

assets_content = Assets::FileContent.new( log, "#{Dir.pwd}/assets" )

assets_controller = AssetsController.new( assets_content )

report_conn = PG::Connection.open( db_params ) 

time_series_controller = TimeSeriesController.new( model_data )

report_controller = ReportController.new( log, report_conn )

redirect_controller = RedirectController.new( log)

# these controllers ought to be put in the constroller module namespace
# then we can refer to them Controller::Session 

general_controllers = [ 
  LogRequestController.new( http_log ),
  redirect_controller, 
  SessionController.new(),
  URLRewriteController.new(),
  assets_controller, 
  time_series_controller, 
  AuthController.new(),
  report_controller ,
  CachePolicyController.new(),
  NotFoundController.new(),
  SendResponseController.new(),
  LogResponseController.new( http_log)
] 


application = Application.new( log, general_controllers )

server = Server::Processor.new(http_log)



server.start_ssl(1443) do |socket|
  application.process_request( socket)
end

server.start(8000) do |socket|
  application.process_request( socket)
end


# id = -1

# start processing at event tip less 2000
#id = event_conn.exec_params( "select max(id) - 10000 as max_id from events" )[0]['max_id']
id = event_conn.exec_params( "select max(id) - 1000 as max_id from events" )[0]['max_id']
#id = 63464 

log.warn( "processing historic events from #{id}")
id = event_processor.process_events( id )

log.warn( "waiting for current events at #{id}")
event_processor.process_current_events( id )

# block
server.run()


