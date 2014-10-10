#!/usr/bin/ruby

require 'logger'
require 'pg'

require './domain/es_model'

# it would be nice to simplify this so we can use simple blocks...
# and have a receive queue, and a write queue, with extremely 
# simple interfaces ... 

# eg.
# queue( conn).run do |id,msg|  end



log = Logger.new(STDOUT)
log.level = Logger::INFO

db_params = { 
  :host => '127.0.0.1', 
  :dbname => 'prod', 
  :port => 5432, 
  :user => 'events_ro', 
  :password => 'events_ro' 
}

conn = PG::Connection.open( db_params )
Model::Consumer.new( log, conn ).each do |id, msg, t, content|

    puts "id #{id} t #{t}"
end



