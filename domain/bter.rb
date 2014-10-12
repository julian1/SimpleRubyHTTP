
# We need to organise into { exchange,  pair,  field } 
# if we really want to construct a group with intersecting time,
# then we can reparse the model stuff. 

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
      'ask_30' => '#ffb0b0',
      'ask_10' => '#ff7ff7',
      'top_ask' => 'red',
      'top_bid' => '#0000ff',
      'bid_10' => '#7f7fff',
      'bid_30' => '#b0b0ff'
    }
    @model_['unit'] = { 
      'ask_30' => 'aud',
      'ask_10' => 'aud',
      'top_ask' => 'aud',
      'top_bid' => 'aud',
      'bid_10' => 'aud',
      'bid_30' => 'aud'
    }
  end



  # sum the depth
  # what is price * order size = ? 

  def sum_book( half_orderbook )

      half_orderbook.inject(0.0) do |xs, row |
        xs + row[0].to_f * row[1].to_f
      end
  end


  def myfunction( half_orderbook, orderbook_sum )

    init = { 
      :sum => 0.0, 
      :price_0 => nil,
      :price_10 => nil, 
      :price_30 => nil
    }

    result = half_orderbook.inject( init) do |acc, row |

      sum = acc[:sum] + row[0].to_f * row[1].to_f

      if( acc[:price_0].nil?)
        acc[:price_0] = row[0]
      end
      if( acc[:price_10].nil? && sum > orderbook_sum * 0.1)
        acc[:price_10] = row[0]
      end
      if( acc[:price_30].nil? && sum > orderbook_sum * 0.3)
        acc[:price_30] = row[0]
      end

      #puts "price #{row[0]}, vol #{row[1].to_i},  sum #{acc}"
# 
      { :sum => sum, 
        :price_0 => acc[:price_0], 
        :price_10 => acc[:price_10], 
        :price_30 => acc[:price_30]  
      }
    end

    if( result[:price_10] === nil )
      result[:price_10] = half_orderbook.last[0]
    end

    if( result[:price_30] === nil )
      result[:price_30] = half_orderbook.last[0]
    end
    result
  end




  # change name to just event() ?
  def event( id, msg, t, content)

    if msg == 'order2' \
      && content['url'] == 'http://data.bter.com/api/1/depth/btsx_btc'
      begin
        orderbook = content['data']

        orderbook['bids'] = orderbook['bids'].sort { |a,b| b[0] <=> a[0] } # largest value first
        orderbook['asks'] = orderbook['asks'].sort { |a,b| a[0] <=> b[0] } # smallest value first

#        top_bid = orderbook['bids'].first[0]
        top_ask = orderbook['asks'].first[0]

 

        total_sum = sum_book( orderbook['bids']) + sum_book( orderbook['asks']) 

        bids = myfunction( orderbook['bids'], total_sum )
        asks = myfunction( orderbook['asks'], total_sum )

        #puts "bid_sum #{bid_sum}, ask_sum #{ask_sum}"

#         puts "top_bid #{top_bid} top_ask #{top_ask}  "
##         puts "\n\n"
# 
        elt = { 
          'id' => @count,
          'time' => t, 

          'ask_30' => asks[:price_30],
          'ask_10' => asks[:price_10],
          'top_ask' => asks[:price_0],
          'top_bid' => bids[:price_0],
          'bid_10' => bids[:price_10],
          'bid_30' => bids[:price_30]
        }

        #puts elt

      @model_['data'] << elt

        @count += 1
      rescue
        @log.info( "Failed to decode orderbook error: #{$!}" )
      end		 
    end
  end
end



