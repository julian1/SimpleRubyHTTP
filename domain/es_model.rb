
require 'json'
require 'pg'
require 'date'
require 'logger'

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


  class EventSink

    def initialize( log, model)
      @log = log
      @model = model
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

    def process_bitstamp_orderbook_event( id, orderbook)
      begin
        time = Time.at(orderbook['timestamp'].to_i).to_datetime
        top_bid = orderbook['bids'][0][0]
        top_ask = orderbook['asks'][0][0]

        bids = orderbook['bids'].length
        asks = orderbook['asks'].length
        ratio = (bids.to_f / asks.to_f * 100 ).round(1) # percent

        bids_sum = compute_sum(orderbook['bids'])
        asks_sum = compute_sum(orderbook['asks'])
        sum_ratio = ((bids_sum.to_f / asks_sum.to_f) * 100 ) .round(1) 

        @model << {
          :id => id,
          :time => time,
          :top_bid => top_bid,
          :top_ask => top_ask,
          :ratio => ratio,
          :sum_ratio => sum_ratio
        }
      rescue
          @log.info( "Failed to decode bitstamp orderbook orderbook error: #{$!}" )
      end
    end


    # process an event
    #def process_event( id, msg, t, content)
    def process_event( id, msg, t, content)
      case msg
        when "error"
          # an error here, is treated as operational
          @log.info( "got event error type")

        when 'order2'
          # new style order event
          # puts "url #{content['url']}"
          case content['url']
            when 'https://www.bitstamp.net/api/order_book/'
              process_bitstamp_orderbook_event( id, content['data'] )
            when 'https://www.bitstamp.net/api/ticker/'
            when 'https://api.btcmarkets.net/market/BTC/AUD/orderbook'
            when 'https://api.btcmarkets.net/market/BTC/AUD/trades'
            else
              @log.warn( "got something unknown")
            end

        when 'order'
          # old style - order
          process_bitstamp_orderbook_event( id, content )

        when 'ticker'
          # old style bitstamp ticker
        else

            @log.warn( puts "unknown event msg #{msg}" )
        end
    end
  end



#   # cqrs, this is like a view - read only
#   # a model presentation class
#   # or a View Model.
#   class ModelReader
# 
#     # the json and http bits here should be moved
#     # into the time series controller.
# 
#     def initialize( log, model)
#       @log = log
#       @model = model
#     end
# 
#     def get_series( x, ticks)
#       # should be a stream not stringstream
# 
#       # take up to 500 elts, with logic to handle fewer
#       take = ticks #500
#       n = @model.length
#       m = @model[ (n - take > 0 ? n - take : 0) .. n - 1]
# 
#       top_ask = m.map do |row| <<-EOF
#         {
#           "id": "#{row[:id]}",
#           "time": "#{row[:time]}",
#           "top_ask": #{row[:top_ask]},
#           "top_bid": #{row[:top_bid]},
#           "sum_ratio": #{row[:sum_ratio]}
#         }
#         EOF
#       end
# 
#       ret = <<-EOF
#         [ #{top_ask.join(", ")} ]
#       EOF
# 
#       x[:response] = "HTTP/1.1 200 OK"
#       x[:response_headers]['Content-Type'] = "application/json"
#       x[:body] = StringIO.new( ret, "r")
#     end
# 
# 
# 
# 
# 
#     def get_id( x )
#       x[:response] = "HTTP/1.1 200 OK"
#       x[:response_headers]['Content-Type'] = "application/json"
#       x[:body] = StringIO.new( "\"#{@model.last[:id]}\"" )
#     end
# 
# #     def get_time()
# #       "\"#{@model.last[:time]}\""
# #     end
# 
#   end
# 
end
