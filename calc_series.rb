
require 'json'
require 'pg'
require 'date'

# we can actually have multiple models if we want. or multiple event processors 


# model1( processor) , model2( processor)
# or
# model( processor1, processor2 ) 
# or
# model1( processor1), model2( processor2)
#
#
# also we can route the message cracking down into this class.
# so 
# this is very interesting. 


module Model 


  # i think we should use >= as it's more logical 
  # basically process from

  def Model.process_events( conn, id, f )
    # process from id, and return the next unprocessed id
    # could use postgres cursors or something more complicated to batch/stream, but
    # this will do for now
    batch = 50
    count = 0
    begin 
      # puts "retrieving events - from #{id}"
      res = conn.exec_params( "select id, t, msg, content from events where id >= $1 order by id limit $2", [id, batch] )
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
            $stderr.puts "Error decoding json content: #{id} error: #{$!}"
          end
          f.call(id, msg, t, content)
        rescue
          # for some reason we aer getting errors 
          $stderr.puts "Error processing message id: #{id} error: #{$!}"
        end
      end
      # puts "count is #{count}"
      id += 1 if count > 0
    end while count > 0
    # return the next event to process
    id
  end

  # ok, we got a problem that we are increasing the id, 

  # need to pass the id
  def Model.process_current_events( conn, id, f )
    puts "current events - next id to process #{id}"
    while true
      begin 
        conn.async_exec "LISTEN events_insert"
        conn.wait_for_notify do |channel, pid, payload|
        puts "Received a NOTIFY on channel #{channel} #{pid} #{payload}"
        # puts "here0 current id #{id}" 
        id = process_events( conn, id, f ) 
      end
      ensure
        conn.async_exec "UNLISTEN *"
      end
    end
  end


  class EventProcessor
    def initialize()
    @model = []
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
        ratio = (bids.to_f / asks.to_f ).round(3) 

        bids_sum = compute_sum(orderbook['bids']) 
        asks_sum = compute_sum(orderbook['asks']) 
        sum_ratio = (bids_sum.to_f / asks_sum.to_f).round(3) 

        @model << { 
          :id => id, 
          :time => time, 
          :top_bid => top_bid, 
          :top_ask => top_ask, 
          :ratio => ratio, 
          :sum_ratio => sum_ratio
        } 
      rescue
          $stderr.puts "Failed to decode bitstamp orderbook orderbook error: #{$!}"
      end
    end 


    # process an event 
    def process_event( id, msg, t, content)
      case msg 
        when "error"
            puts "got event error type"

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
              puts "unknown url #{content['url']}"
            end

        when 'order'
          # old style - order
          process_bitstamp_orderbook_event( id, content )

        when 'ticker'
          # old style bitstamp ticker
        else
            puts "unknown event msg #{msg}"
        end
    end

    # access the current model state  
    # this can be performed at any time ...
    # or pushed into the db, etc.


    # so i think rather than do the formatting, it would be better to just send 
    # the series data, and handle presentation in javascript. 

    def get_series( x)
      # to be fast, we should really use a stream 
      # should be a join, 

      puts "$$ model length #{@model.length}"


      # take up to 500 elts
      take = 500
      n = @model.length
      m = @model[ (n - take > 0 ? n - take : 0) .. n - 1]
      

      top_ask = m.map do |row| <<-EOF
          { 
            "id": "#{row[:id]}", 
            "time": "#{row[:time]}", 
            "top_ask": #{row[:top_ask]}, 
            "top_bid": #{row[:top_bid]},
            "sum_ratio": #{row[:sum_ratio]}

          }
        EOF
      end

      ret = <<-EOF 

        [ #{top_ask.join(", ")} ] 

      EOF

      x[:response] = "HTTP/1.1 200 OK\r\n"
      x[:response_headers]['Content-Type:'] = "application/json\r\n"
      x[:body] = StringIO.new( ret, "r")
    end


#     def get_time()
#       "\"#{@model.last[:time]}\""
#     end
 

    def get_id( x )
      x[:response] = "HTTP/1.1 200 OK\r\n"
      x[:response_headers]['Content-Type:'] = "application/json\r\n"
      x[:body] = StringIO.new( "\"#{@model.last[:id]}\"" )
    end


  end
end

