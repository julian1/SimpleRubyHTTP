

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
	return if x[:response]

#     # the ? isn't quite right here, it shouldn't be optional
#     # if there's a param set.
#     matches = /^GET \/get_all_series.json\??(.*)$/.match(x[:request])
#     if matches && matches.captures.length == 1
# 
#       abort('not supported anymore' )
# 
#       #puts "raw query string #{ matches.captures[0] }"
#       fields = decode_url_args( matches.captures[0])
#       #puts "fields #{fields}"
#       # defaults
#       ticks = fields['ticks'] ? fields['ticks'].to_i : 100
#       interval = fields['interval'] ? fields['interval'].to_i : 1
#       #puts "model length #{@model.length }"
#       # @model.get_series( x, ticks)
#       # take up to 500 elts, with logic to handle fewer
#       take = ticks
#       n = @model.length
#       m = @model[ (n - take > 0 ? n - take : 0) .. n - 1]
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
#       ret = <<-EOF
#         [ #{top_ask.join(", ")} ]
#       EOF
#       # puts ret
#       x[:response] = "HTTP/1.1 200 OK"
#       x[:response_headers]['Content-Type'] = "application/json"
#       x[:body] = StringIO.new( ret, "r")
#     end
# 
# 


# we want a tick interval.. 1m 10m 1hr 1day
# perhaps we should be creating these as separate streams/series rather than trying to filter them ?  
# it would be faster.
# it just becomes another event. 

# event( { type 'series' :name  :value } ); 

# EXTREMELY IMPORTANT - how we store it - eg. to @model should be done by the end of the chain 

    # an individual series
    matches = /^GET \/get_series.json\??(.*)$/.match(x[:request])
    if matches && matches.captures.length == 1

      fields = decode_url_args( matches.captures[0])
      #puts "fields #{fields}"

      ticks = fields['ticks'] ? fields['ticks'].to_i : 100
      name = fields['name'] 
      take = ticks

      series_name, field_name = name.split('.')

      series = @model[series_name]['data']
      n = series.length
      m = series[ (n - take > 0 ? n - take : 0) .. n - 1]

      
      color = @model[series_name]['color'][field_name]
      unit = @model[series_name]['unit'][field_name]

      # puts "color: #{color}, unit: #{unit}"
  
      values = m.map do |row| 
        <<-EOF
        { 
          "time": "#{row['time'] }",
          "value": #{row[field_name]} 
        }
        EOF
      end

      ret = <<-EOF
        {
          "name": "#{name}",
          "first_id": #{ m.first['id'] },
          "last_id": #{ m.last['id'] },
          "color": "#{color}",
          "unit": "#{unit}",
          "data": [ #{values.join(", ")} ]
        }
      EOF

       #puts ret
      x[:response] = "HTTP/1.1 200 OK"
      x[:response_headers]['Content-Type'] = "application/json"
      x[:body] = StringIO.new( ret, "r")
    end




    # this whole id thing, where client submits id to check for state change, is
    # almost equivalent to etag approach

	# it's a substitute for haskell type laziness - where we just request.
    matches = /^GET \/get_series_id.json\??(.*)$/.match(x[:request])
    if matches && matches.captures.length == 1

      fields = decode_url_args( matches.captures[0])
      name = fields['name'] 

      series_name, field_name = name.split('.')
      series = @model[series_name]['data']

#      puts "id for #{name} is #{ series.last['id'] } " 

      x[:response] = "HTTP/1.1 200 OK"
      x[:response_headers]['Content-Type'] = "application/json"
      # shouldn't need quoting
      x[:body] = StringIO.new( "\"#{series.last['id']}\"" )

    end

  end
end


