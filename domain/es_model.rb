
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

    ## ok, the issue is that we cannot return a value to indicate that there's 
    ## nothing more to process

    ## actually we could pass a continuation to run ? 
    ## if we can bind over stuff. 
    ## eg. so when we've processed all the historic events. 
    ## we instead 
  
    ## a completion continuation. - if we could partially bind. 
    ## select 
   

    ## ruby partial application...
 
    def get_event_tip( conn, &code )
  #    EM.run do
        df = conn.query_defer("select max(id) - 1000 as max_id from events" )
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
        
            puts "processed records - count is #{count}"
            if count > 0
          
              ### ok, the reason it's not getting called is because
              ### we have recusion. 

              ### note we use & to turn it into a block again..
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

# 
# 
#       # process from id, and return the next unprocessed id
#       # could use postgres cursors or something more complicated to batch/stream, but
#       # this will do for now
#       batch = 50
#       count = 0
#       begin
#         # puts "retrieving events - from #{id}"
#         res = @conn.exec_params( "select id, t, msg, content from events where id >= $1 order by id limit $2", [id, batch] )
#         count = 0
#         res.each do |row|
#           begin
#             # process id, first to avoid exceptions being rechanged
#             count += 1
#             id = row['id'].to_i
#             t = DateTime.parse( row['t'] )
#             msg = row['msg']
#             begin
#               content = JSON.parse( row['content'] )
#             rescue
#               @log.warn( "Error decoding json content: #{id} error: #{$!}" )
#             end
#             @event_sink.event(id, msg, t, content)
#           rescue
#             # for some reason we aer getting errors
#             @log.warn( "Error processing message id: #{id} error: #{$!}" )
#           end
#         end
#         # puts "count is #{count}"
#         id += 1 if count > 0
#       end while count > 0
#       # return the next event to process
#       id


    
    def process_current_events( id)
      @log.info( "current events - next id to process #{id}")
      while true
        begin
          @conn.async_exec "LISTEN #{POSTGRES_CHANNEL}"
          @conn.wait_for_notify do |channel, pid, payload|

            #@log.debug( "Received a NOTIFY on channel #{channel} #{pid} #{payload}" )
            id = process_events( id )
          end
        ensure
          @conn.async_exec "UNLISTEN *"
        end
      end
    end


    def sync_and_process_current_events()
      # id = -1
      # start processing at event tip less 2000
      id = @conn.exec_params( "select max(id) - 1000 as max_id from events" )[0]['max_id']
      @log.warn( "processing historic events from #{id}")
      id = process_events( id )
      @log.warn( "waiting for current events at #{id}")
      process_current_events( id )
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
        @sinks.each do |sink|
          sink.event( id, msg, t, content) 
        end
    end
  end

  class Consumer
    class ConsumerSink
      # helper class for consumer
      def initialize( code )
        @code = code
      end
      def event( id, msg, t, content)
        @code.call( id, msg, t, content) 
      end
    end

    def initialize( log, conn )
      @log = log
      @conn = conn 
      @event_processor = Model::EventProcessor.new( @log, @conn, nil )
    end

    def each( &code )
      @event_processor.event_sink = ConsumerSink.new( code )
      # id = -1
      # start processing at event tip less 2000
      id = @conn.exec_params( "select max(id) - 100 as max_id from events" )[0]['max_id']
      @log.warn( "processing historic events from #{id}")
      id = @event_processor.process_events( id )
      @log.warn( "waiting for current events at #{id}")
      @event_processor.process_current_events( id )
    end
  end


  class Producer
    def initialize( conn)
      @conn = conn
    end
    def enqueue( msg, content )
      # we should not be exposing this, instead use a queue/stream/events writer. 
      #@conn.exec_params( 'select enqueue( $$order2$$, $1::json )', [json] )
      @conn.exec_params( 'select enqueue( $1::varchar, $2::json )', [msg, json] )
    end 
  end

end



