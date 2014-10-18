#!/usr/bin/ruby


#require './support/server'
require './support/assets'
require './support/application'

require './domain/es_model'
require './domain/btcmarkets'
require './domain/bitstamp'
require './domain/bter'


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
require 'rubygems'
require 'eventmachine'


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


http_log_file = File.new('log.txt', 'w')
http_log_file.sync = 1
http_log = Logger.new( http_log_file  )
http_log.level = Logger::DEBUG
#http_log_file = Logger.new(STDOUT)
#http_log.level = Logger::INFO

# we can separate out http requests from everything else by
# just creating two loggers
log = Logger.new(STDOUT)
#log.level = Logger::WARN
log.level = Logger::DEBUG

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

# it's not just the model data, it's also the logger, that's shared
# between threads. and the assets class, etc 
# basically everything that's shared has to start having mutexes put around
# it. 
# unless we put the processing on a queue. 

# even if we put it on a queue - the socket.gets is designed to block, until 
# it gets a connection. 

# can we write this async.

# Ok, very important - we successfully do the accept - without having to 
# throw a new thread. 
# so perhaps we can throw it into a select statement or something. 

# except socket read and socket write probably aren:w


model_data = { } 

sinks = [
    # ESModel::BitstampModel.new( model_data ),
    BitstampModel.new( log, model_data ),
    BTCMarketsModel.new( log, model_data),
	BterModel.new( log, model_data)
]

event_sink = Model::EventSink.new( sinks )

event_conn = PG::Connection.open( db_params ) 

event_processor = Model::EventProcessor.new( log, event_conn, event_sink )

assets_content = Assets::FileContent.new( log, "#{Dir.pwd}/assets" )

assets_controller = AssetsController.new( assets_content )

report_conn = PG::Connection.open( db_params ) 

time_series_controller = TimeSeriesController.new( model_data )

report_controller = ReportController.new( log, report_conn )

#redirect_controller = RedirectController.new( log, '127.0.0.1', 8443)

# these controllers ought to be put in the constroller module namespace
# then we can refer to them Controller::Session 

general_controllers = [ 
#  LogRequestController.new( http_log ),
#  redirect_controller, 
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


# Thread.new {
# 
#  event_processor.sync_and_process_current_events()
# }
# 

# server = Server::Processor.new(http_log)
# 
# 
# # ssl
# server.start_ssl(8443) do |socket|
#   application.process_request( socket)
# end
# 
# server.start(8000) do |socket|
#   application.process_request( socket)
# end
# 

class Server < EventMachine::Connection
    attr_accessor :application
    def receive_data(data)
		# now pass the data and ourselves(so we can send a response) to the application.
		@application.process_request_new( self, data)
    end
end


require 'pg/em'

conn = PG::EM::Client.new db_params 

POSTGRES_CHANNEL = 'events_insert'

# does this set up a recursion that don't want 
# and will it miss listening events - actually doesn't matter if we miss
# because we always gobble up missing ids ...
def myfunc( conn )
  EM.run do
    # set up the call back first
    conn.wait_for_notify_defer(3).callback do |notify|
      if notify
        puts "Someone spoke to us on channel: #{notify[:relname]} from #{notify[:be_pid]}"
        # how do we stay subscribed ...
        # continuing to listen for events ...
        myfunc( conn)
      else
        puts "Too late, 7 seconds passed"
        myfunc( conn)
      end
    end.errback do |ex|
      puts "Connection to db lost... #{ex} "
    end
    pg.query_defer("LISTEN #{POSTGRES_CHANNEL}")
  end
end


## ok, now rather than having linear code, 
## we have to structure all this with callbacks ...
## eg. get historic 

## the get 50 results, will need to be a recursion rather than a loop.


EM.run do

  EM.start_server '0.0.0.0', 8000, Server do |server|
    server.application = application
  end


# 	  # asynchronous + deferrable
#   EM.run do
#     df = pg.query_defer('select count(*) from events')
#     df.callback { |result|
#       puts Array(result).inspect
#       #EM.stop
#     }
#     df.errback {|ex|
#       raise ex
#     }
#     puts "finished"
#   end
# 

  # if we put this in a function then we can just call recursively? 
  
#  myfunc( conn)

  #event_processor.process_events( conn , 0 )

  event_processor.get_event_tip( conn )



end

## ok, this thing is on another thread ????

# 
# # start sync and process events
# event_processor.sync_and_process_current_events()
# 
# 
# # block
# server.run()
# 
# 
