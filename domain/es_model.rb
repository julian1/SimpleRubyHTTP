
require 'json'
require 'pg'
require 'date'
require 'logger'


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
module Model



  class EventProcessor

    def initialize( log, conn, event_sink)
      @log = log
      @conn = conn
      @event_sink = event_sink
    end


    def process_events( id )
      # process from id, and return the next unprocessed id
      # could use postgres cursors or something more complicated to batch/stream, but
      # this will do for now
      batch = 50
      count = 0
      begin
        # puts "retrieving events - from #{id}"
        res = @conn.exec_params( "select id, t, msg, content from events where id >= $1 order by id limit $2", [id, batch] )
        count = 0
        res.each do |row|
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
            @event_sink.process_event(id, msg, t, content)
          rescue
            # for some reason we aer getting errors
            @log.warn( "Error processing message id: #{id} error: #{$!}" )
          end
        end
        # puts "count is #{count}"
        id += 1 if count > 0
      end while count > 0
      # return the next event to process
      id
    end


    # channel to wait on
    POSTGRES_CHANNEL = 'events_insert'

    # need to pass the id
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
  end



  class BTCMarketsModel

    # rather than try to combine the data and metadata, do them 
    # with separate javascript calls ?

    def initialize( model)
      @model = model
      @model['btcmarkets'] = { } 
      @model['btcmarkets']['data'] = [ ] 
      @model['btcmarkets']['color'] = { 
        'top_bid' => 'blue',
        'top_ask' => 'red'
      }
   #   @model['btcmarkets'].axis = 123

      # the parameters could use different axis, colors, 
      # set up metadata here.
      # can we set the axis ?
      # yes with an init...
    end

    def process_event( id, msg, t, content)

      if msg == 'order2' \
        && content['url'] == 'https://api.btcmarkets.net/market/BTC/AUD/orderbook'
        begin
          orderbook = content['data']
          #puts orderbook
          time = Time.at(orderbook['timestamp'].to_i).to_datetime
          #puts "time #{time}"
          top_bid = orderbook['bids'][0][0]
          top_ask = orderbook['asks'][0][0]
         # puts orderbook['bids'][0]
          @model['btcmarkets']['data'] << { 
            'time' => time, 
            'top_bid' => top_bid, 
            'top_ask' => top_ask
          }
        rescue
            @log.info( "Failed to decode btcmarkets orderbook orderbook error: #{$!}" )
        end		 
      end
    end
  end



  class BitstampModel
    # change name to stream, or sink, 
    # this is really just the target of a fold

    def initialize( model)
      @model = model

      # set up data andjjj metadata here.
      @model['bitstamp'] = { } 
      @model['bitstamp']['data'] = [ ] 
      # we can now specify some semantic meaning
      # axis, etc
      @model['bitstamp']['color'] = { 
        'top_bid' => 'blue',
        'top_ask' => 'red',
        'ratio' => 'grey',
        'sum_ratio' => 'grey'
      }

    end

    def compute_sum(data)
      bids_sum = 0
      data.each do |i|
        price = i[0].to_f
        quantity = i[1].to_f
        bids_sum += price * quantity
      end
      bids_sum.to_i
    end

    # we should be using different clases, for the
    # different event sources that we use.

    def process_event( id, msg, t, content)
      case msg
        when 'order2'
          # new style order event
          # puts "url #{content['url']}"
          if content['url'] == 'https://www.bitstamp.net/api/order_book/'
              process( id, content['data'] )
          end
        when 'order'
          # old style - order
          process( id, content )
        end
    end

    def process( id, orderbook)
      begin
        time = Time.at(orderbook['timestamp'].to_i).to_datetime
        top_bid = orderbook['bids'][0][0]
        top_ask = orderbook['asks'][0][0]

        bids = orderbook['bids'].length
        asks = orderbook['asks'].length
        ratio = (bids.to_f / asks.to_f * 100 ).round(1) # percent

        bids_sum = compute_sum(orderbook['bids'])
        asks_sum = compute_sum(orderbook['asks'])

        # this calculation isn't really correct. 
        # it should be bids / (bids + asks ) * 100 
        sum_ratio = ((bids_sum.to_f / asks_sum.to_f) * 100 ) .round(1) 

        @model['bitstamp']['data'] << { 
          'originating_id' => id,
          'time' => time,
          'top_bid' => top_bid,
          'top_ask' => top_ask,
          'ratio' => ratio,
          'sum_ratio' => sum_ratio
        }
      rescue
        @log.info( "Failed to decode bitstamp orderbook orderbook error: #{$!}" )
      end
    end
  end


  class EventSink

    def initialize( log, model)
      @log = log

      # shouldn't really init here - but do it for now. 
      @sinks = [
        BitstampModel.new( model),
        BTCMarketsModel.new( model)
      ]
    end
    ### VERY IMPORTANT any fold operation has an initial argument.
    ### we really need this. could be used to set axis data

    def process_event( id, msg, t, content)
        @sinks.each do |sink|
          sink.process_event( id, msg, t, content) 
        end
    end
  end

end



