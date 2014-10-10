#!/usr/bin/ruby

require 'logger'
require 'pg'


require './domain/es_model'


class EventSink

  def event( id, msg, t, content)
    puts "event #{id} #{msg} #{t}" 
  end
end

event_sink = EventSink.new()


log = Logger.new(STDOUT)
log.level = Logger::INFO

db_params = { 
  :host => '127.0.0.1', 
  :dbname => 'prod', 
  :port => 5432, 
  :user => 'events_ro', 
  :password => 'events_ro' 
}


event_conn = PG::Connection.open( db_params ) 

event_processor = Model::EventProcessor.new( log, event_conn, event_sink )


# start sync and process events
event_processor.sync_and_process_current_events()


