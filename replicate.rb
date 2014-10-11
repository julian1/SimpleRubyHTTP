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


consumer_db_params = { 
  :host => '147.69.40.170', 
  :dbname => 'prod', 
  :port => 5432, 
  :user => 'events_ro', 
  :password => 'events_ro' 
}

myid = -1

consumer_conn = PG::Connection.open( consumer_db_params )

Model::Consumer.new( log, consumer_conn ).each do |id, msg, t, content|
    myid = id if myid == -1
    abort( 'mismatch' ) if id != myid
    myid += 1
    puts "id #{id}, t #{t}"
end



