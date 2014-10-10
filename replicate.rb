#!/usr/bin/ruby

require 'logger'
require 'pg'


require './domain/es_model'

# it would be nice to simplify this so we can use simple blocks...
# and have a receive queue, and a write queue, with extremely 
# simple interfaces ... 

# eg.
# queue( conn).run do |id,msg|  end

class EventSink

  def initialize( code )
    @code = code
  end

  def event( id, msg, t, content)
    #puts "event #{id} #{msg} #{t}" 
    @code.call( id, msg, t, content) 
  end
end

#event_sink = EventSink.new()


log = Logger.new(STDOUT)
log.level = Logger::INFO

db_params = { 
  :host => '127.0.0.1', 
  :dbname => 'prod', 
  :port => 5432, 
  :user => 'events_ro', 
  :password => 'events_ro' 
}

#conn = PG::Connection.open( db_params ) 
#event_processor = Model::EventProcessor.new( log, conn, event_sink )

# start sync and process events
#event_processor.sync_and_process_current_events()


class Consumer
  
  def initialize( log, db_params)
    @log = log
    @conn = PG::Connection.open( db_params ) 
    @event_processor = Model::EventProcessor.new( @log, @conn, nil )
  end

  def each( &code )
    # if we pass the proc here, then how do we set it in the event sink ?
    # maybe easy. we just set a new event sink 

      event_sink = EventSink.new( code )
      @event_processor.event_sink = event_sink 

      # id = -1
      # start processing at event tip less 2000
      id = @conn.exec_params( "select max(id) - 1000 as max_id from events" )[0]['max_id']
      @log.warn( "processing historic events from #{id}")
      id = @event_processor.process_events( id )
      @log.warn( "waiting for current events at #{id}")
      @event_processor.process_current_events( id )
  end
end


Consumer.new( log, db_params ).each do |id, msg, t, content|

    puts "id #{id}"
end





