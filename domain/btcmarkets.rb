


## these BTCMarkets and Bitstamp are specific instances of sinks, they should move
## to separate files in the domain .

class BTCMarketsModel

  # rather than try to combine the data and metadata, do them 
  # with separate javascript calls ?

  def initialize( log, model)
    @log = log
    @model = model
    @model['btcmarkets'] = { } 
    @model['btcmarkets']['data'] = [ ] 
    @model['btcmarkets']['color'] = { 
      'top_bid' => 'blue',
      'top_ask' => 'red'
    }
    @model['btcmarkets']['unit'] = { 
      'top_ask' => 'aud',
      'top_bid' => 'aud'
    }


  end

  # change name to just event() ?
  def event( id, msg, t, content)

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



