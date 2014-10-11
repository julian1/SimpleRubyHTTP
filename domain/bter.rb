

## these BTCMarkets and Bitstamp are specific instances of sinks, they should move
## to separate files in the domain .

class BterModel

  # rather than try to combine the data and metadata, do them 
  # with separate javascript calls ?

  def initialize( log, model)
    @log = log
    @model = model
    @count = 0

    @model['btsx_btc'] = {} 

	@model_  = @model['btsx_btc']

    @model_['data'] = [] 
    @model_['color'] = { 
      'top_bid' => 'blue',
      'top_ask' => 'red'
    }
    @model_['unit'] = { 
      'top_ask' => 'aud',
      'top_bid' => 'aud'
    }
  end

  # change name to just event() ?
  def event( id, msg, t, content)

    if msg == 'order2' \
      && content['url'] == 'http://data.bter.com/api/1/depth/btsx_btc'
      begin
        orderbook = content['data']
#        puts orderbook
#         time = Time.at(orderbook['timestamp'].to_i).to_datetime
#         #puts "time #{time}"
         top_bid = orderbook['bids'].last[0]
		top_ask = orderbook['asks'].last[0] 
		#	puts "top_bid #{top_bid} top_ask #{top_ask}  "
        @model_['data'] << { 
          'id' => @count,
          'time' => t, 
          'top_bid' => top_bid, 
          'top_ask' => top_ask
        }
        @count += 1
      rescue
        @log.info( "Failed to decode orderbook error: #{$!}" )
      end		 
    end
  end
end



