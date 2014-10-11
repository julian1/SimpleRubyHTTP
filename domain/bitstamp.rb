
class BitstampModel
  # change name to stream, or sink, 
  # this is really just the target of a fold

  def initialize( log, model)
    @log = log
    @model = model
    @count = 0

    # set up data andjjj metadata here.
    @model['bitstamp'] = { } 
    @model['bitstamp']['data'] = [ ] 
    # we can now specify some semantic meaning
    # axis, etc
    @model['bitstamp']['color'] = { 
      'top_ask' => 'red',
      'top_bid' => 'blue',
      'ratio' => 'grey',
      'sum_ratio' => 'grey'
    }
    # rather than specify the axis - we should specify the unit
    # then, client can map to axis. because we don't know axis1 axis2 are not named. 
    # we should label the axis on client side with unit to make this easy.
    @model['bitstamp']['unit'] = { 
      'top_ask' => 'usd',
      'top_bid' => 'usd',
      'ratio' => 'percent',
      'sum_ratio' => 'percent'
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

  def event( id, msg, t, content)
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
        'id' => @count,
        'originating_id' => id,
        'time' => time,
        'top_bid' => top_bid,
        'top_ask' => top_ask,
        'ratio' => ratio,
        'sum_ratio' => sum_ratio
      }
      @count += 1

    rescue
      @log.info( "Failed to decode bitstamp orderbook orderbook error: #{$!}" )
    end
  end
end


