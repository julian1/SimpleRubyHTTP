
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
      'top_bid' => 'blue'
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

        # why isn't there a fucking fold? 
        # orderbook['bids'] = [[2,3],[4,5]]

        # we should actually ensure they are sorted correctly by price

        orderbook['bids'].sort { |a,b| a[0] <=> b[0] }
        orderbook['asks'].sort { |a,b| a[0] <=> b[0] } # might want to reverse ...

        bid_sum = orderbook['bids'].inject(0.0) do |xs, row |
          xs + row[0].to_f * row[1].to_f
        end
        ask_sum = orderbook['asks'].inject(0.0) do |xs, row |
          xs + row[0].to_f * row[1].to_f
        end
        total_sum = bid_sum + ask_sum
          
        init = { :sum => 0.0, :price_10 => nil }
        result = orderbook['bids'].inject( init) do |xs, row |
          sum = xs[:sum] + row[0].to_f * row[1].to_f

          if( init[:price_10].nil? && sum > total_sum * 0.1)
            init[:price_10] = row[0]
            puts "whoot #{row[0]}"
          end
          puts "price #{row[0]},  sum #{xs}"
          { :sum => sum, :price_10 => init[:price_10] } 
        end


        puts "bid_sum #{bid_sum}, ask_sum #{ask_sum}"

        puts "\n\n"

        # puts "top_bid #{top_bid} top_ask #{top_ask}  "
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



