
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
      'top_ask' => 'red',
      'top_bid' => '#0000ff',
      'bid_10' => '#7f7fff',
      'bid_30' => '#b0b0ff'
    }
    @model_['unit'] = { 
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

    half_orderbook.inject( init) do |acc, row |

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

#           puts "price #{row[0]},  sum #{acc}"
# 
      { :sum => sum, 
        :price_0 => acc[:price_0], 
        :price_10 => acc[:price_10], 
        :price_30 => acc[:price_30]  
      }
    end
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

#         puts "ask first #{orderbook['asks'].first[0]} last #{orderbook['asks'].first[0]}"
# 
#         orderbook['asks'].each do |row| 
#           puts "ask -> #{ row}" 
#         end
# 

        bid_sum = orderbook['bids'].inject(0.0) do |xs, row |
          xs + row[0].to_f * row[1].to_f
        end
        ask_sum = orderbook['asks'].inject(0.0) do |xs, row |
          xs + row[0].to_f * row[1].to_f
        end

        total_sum = sum_book( orderbook['bids']) + sum_book( orderbook['asks']) 

        result = myfunction( orderbook['bids'], total_sum )

        #puts "bid_sum #{bid_sum}, ask_sum #{ask_sum}"

#         puts "top_bid #{top_bid} top_ask #{top_ask}  "
#         puts "\n\n"
# 
        @model_['data'] << { 
          'id' => @count,
          'time' => t, 
          'top_ask' => top_ask,
          'top_bid' => result[:price_0],
          'bid_10' => result[:price_10],
          'bid_30' => result[:price_30]
        }
        @count += 1
      rescue
        @log.info( "Failed to decode orderbook error: #{$!}" )
      end		 
    end
  end
end



