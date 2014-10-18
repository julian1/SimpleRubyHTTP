
require 'json'
#require 'pg'
require 'date'
require 'logger'

require 'pg/em'

# these classes can be used to set up stream synchronization quite simply.

# VERY IMPORTANT Ok, there is no one-to-one correspondance between id's in different streams
# eg. we monitor multiple urls. only one in four events is actually a specific for the url
# when we monitor four urls.

# we need to refine the idea of the main event stream and then derivative streams.


# THE SERIES WE PRODUCE IS A PROJECTION - A lazy LEFT-FOLD. 
# IDEALLY WE'D LIKE TO BE ABLE TO CREATE MULTIPLE PROJECTIONS
# AND USE THEM INDEPENDENTLY.

# Eg. EACH SERIES - like top_bid IS AN INDEPENDENT FUNCTION not calculated with everything else


# we can actually have multiple models if we want. or multiple event processors
# model1( processor) , model2( processor)
# or
# model( processor1, processor2 )
# or
# model1( processor1), model2( processor2)
#

# we don't need db stuff to be atomic, because the model
# is purely in memory
#

# change name ESModel?
# or Events or Queue ? or Stream  
module Model

  class EventProcessor

    attr_accessor :event_sink

    # channel to wait on
    POSTGRES_CHANNEL = 'events_insert'

    def initialize( log, conn, event_sink)
      @log = log
#      @conn = conn
      @event_sink = event_sink
    end


    def listen_and_process_events( conn, id )
      # this is a recusrive tail function
      # set up the call back first
      conn.wait_for_notify_defer(nil).callback do |notify|
        #puts "Someone spoke to us on channel: #{notify[:relname]} from #{notify[:be_pid]}"
        # should be able to write this more simply
        process_events( conn, id) do |conn, id|
          # pass ourselves
          listen_and_process_events(conn, id)
        end
      end.errback do |ex|
        puts "Connection to db lost... #{ex} "
      end
      conn.query_defer("LISTEN #{POSTGRES_CHANNEL}")
    end

 
    def get_event_tip( conn, &code )
  #    EM.run do
        df = conn.query_defer("select max(id) as max_id from events" )
        df.callback { |result|
          id = result[0]['max_id'].to_i
          puts "max_id is #{id} !!"
          code.call( conn, id )
        } 
        df.errback {|ex|
          raise ex
        }
  #    end
    end


    def process_events( conn, id, &code )
      batch = 50

  #    EM.run do
        df = conn.query_defer("select id, t, msg, content from events where id >= $1 order by id limit $2", [id, batch] )
        df.callback { |result|
          count = 0
          result.each do |row|
              begin
                # process id, first to avoid exceptions being rechanged
                count += 1
                id = row['id'].to_i
                t = DateTime.parse( row['t'] )
                msg = row['msg']
                begin
                  content = JSON.parse( row['content'] )
                rescue
                  @log.warn( "Error decoding json content: #{id} error: #{$!}" )
                end
                @event_sink.event(id, msg, t, content)
              rescue
                # for some reason we aer getting errors
                @log.warn( "Error processing message id: #{id} error: #{$!}" )
              end
            end
        
            #puts "processed records - count is #{count}"
            if count > 0
              ### note we use & to turn it into a block again, to match the argument..
              process_events( conn, id + 1, &code )
            else
              ## call the continuation - but we  
              code.call( conn, id )
            end
        }
        df.errback {|ex|
          raise ex
        }
    #  end

    end
  end


  class EventSink
    ## change name EventSinkDelegator
    ## this specific sink shouldn't really be defined here.
    ## it's actually a Sink delegator/ fan-out

    def initialize( sinks )
      # shouldn't really init here - but do it for now. 
      @sinks = sinks 
    end
    ### VERY IMPORTANT any fold operation has an initial argument.
    ### we really need this. could be used to set axis data

    # change name to just event() ?
    def event( id, msg, t, content)
        # puts "id #{id}"

        @sinks.each do |sink|
          sink.event( id, msg, t, content) 
        end
    end
  end
# 
#   class Consumer
#     class ConsumerSink
#       # helper class for consumer
#       def initialize( code )
#         @code = code
#       end
#       def event( id, msg, t, content)
#         @code.call( id, msg, t, content) 
#       end
#     end
# 
#     def initialize( log, conn )
#       @log = log
#       @conn = conn 
#       @event_processor = Model::EventProcessor.new( @log, @conn, nil )
#     end
# 
#     def each( &code )
#       @event_processor.event_sink = ConsumerSink.new( code )
#       # id = -1
#       # start processing at event tip less 2000
#       id = @conn.exec_params( "select max(id) - 100 as max_id from events" )[0]['max_id']
#       @log.warn( "processing historic events from #{id}")
#       id = @event_processor.process_events( id )
#       @log.warn( "waiting for current events at #{id}")
#       @event_processor.process_current_events( id )
#     end
#   end
# 
# 
#   class Producer
#     def initialize( conn)
#       @conn = conn
#     end
#     def enqueue( msg, content )
#       # we should not be exposing this, instead use a queue/stream/events writer. 
#       #@conn.exec_params( 'select enqueue( $$order2$$, $1::json )', [json] )
#       @conn.exec_params( 'select enqueue( $1::varchar, $2::json )', [msg, json] )
#     end 
#   end
# 
end



