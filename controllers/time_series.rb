
def decode_url_args( capture )
    # should be put in helpers

    # so we replace the + with space and then decode
    query = URI.decode( capture.gsub(/\+/,' ') )

    #puts "got series query '#{query}'"
    # ok, now we want to split the keyvalue pairs

    fields = {}
    query.split('&').each do |pair| 
      id, val = pair.split('=') 
      fields[id] = val
    end
    fields
end


class TimeSeriesController
  # I think that the model reader can actually be turned into this.

  def initialize(model)
    @model = model
  end

  def action(x)
    # the ? isn't quite right here, it shouldn't be optional
    # if there's a param set. 
    matches = /^GET \/get_series.json\??(.*)$/.match(x[:request])
    if matches && matches.captures.length == 1

      puts "raw query string #{ matches.captures[0] }"

      fields = decode_url_args( matches.captures[0])
 
      puts "fields #{fields}"

      # defaults 
      ticks = fields['ticks'] ? fields['ticks'].to_i : 100

      puts "model length #{@model.length }"

      # @model.get_series( x, ticks)

      # take up to 500 elts, with logic to handle fewer
      take = ticks 
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

      # puts ret

      x[:response] = "HTTP/1.1 200 OK"
      x[:response_headers]['Content-Type'] = "application/json"
      x[:body] = StringIO.new( ret, "r")


    end





    # this whole id thing, where client submits id to check for state change, is
    # almost equivalent to etag approach
		
	# it's a substitute for haskell type laziness - where we just request.
    if /^GET \/get_id.json$/.match(x[:request])
#      @model.get_id( x )
      x[:response] = "HTTP/1.1 200 OK"
      x[:response_headers]['Content-Type'] = "application/json"
      x[:body] = StringIO.new( "\"#{@model.last[:id]}\"" )

    end

  end
end


