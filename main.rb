
require './server'
require './static'
require './helper'
require './calc_series'


# chain together transforms...


# Ok aparently ruby blocks can reference their enclosing scope!
# how are we going to pass a reference into into the processing block...



def handle_post_type( x)
  if /POST .*$/.match(x[:request])
      puts "************ got post !!! ***********"
      puts m

      # we must read content , otherwise it gets muddled up
      # it gets read at the next http x[:request], when connection
      # is keep alive. 
      abort()
      Helper.write_hello_message( m, socket )
      return true
  end
end


def strip_http_type( x)
  # determine http x[:request] type
  # we ought to do a bit more here,
  # and strip it.
  matches = /(GET .*)\s(HTTP.*)/.match(x[:request])
  if matches and matches.captures.length == 2
    x[:request] = matches.captures[0] 
    #puts "rewriting to #{x[:request]}" 
  else
    abort()
    #Helper.write_hello_message( m, socket )
    #return true
  end
end 



def rewrite_index_html( x)
  # rewrite top level / to index.html
  if matches = /GET \/$/.match(x[:request])
    x[:request] = "GET /index.html" 
    #puts "rewriting to #{x[:request]}" 
  end
end


def static_resource( x, fileContent)

    puts "**** testing static resource request"

 # static resource
  matches = /GET (.*\.txt|.*\.html|.*\.css|.*\.js|.*\.jpeg|.*\.png)$/.match(x[:request])
  if matches and matches.captures.length == 1

    puts "**** got request static resource "

    # resource = matches.captures[ 0]
    #result = fileContent.serve_file( x[:request] )
    result = fileContent.serve_file( x )

    # ok, now we don't want to be writing the socket. instead we
    # want to just fill in some stuff...
    # Helper.write_response( result.headers, result.io_content, socket )

#     x[:response] = "HTTP/1.1 200 OK\r\n"
#     x[:body] = result.io_content 
#     x[:response_headers] = result.headers
# 
    return true
  end
end


def get_series( x, model )
  # change name get_data or get series etc
  if /GET \/get_series.json$/.match(x[:request])
      model.get_series( x)

  end
end


# ok, we need to bind lexically, or they need to be classes
# or we could stuff things into the message !!! 

def get_id( x, model )
  if /GET \/get_id.json$/.match(x[:request])
#       content_ = model.get_id()  
#       content_io = StringIO.new( content_, "r")
#       Helper.write_json( content_io, socket )
#       return true
# 

      model.get_id( x )
  end
end



def send_response( x)
  # do we have a body and response ?
  
  #Helper.write_response( x[:response_headers], x[:body], x[:socket] )
  Helper.write_response( x )

end


def application( socket, model, fileContent)

  m = Helper.decode_request( socket) 

  # we can still use functions t
  x = {
    :request => m['request'],
    :request_headers => m,
    :socket => socket,
    :response => nil,
    :response_headers => {},
    :body => nil
  }

  puts x[:request]

#  request = x[:request]

  # if the connection was closed by remote
  if x[:request].nil?
    $stderr.puts "eof on https"
    return nil
  end


  # so we have to do some message cracking
  #puts "-------------"
  puts "request is #{ x[:request] }"


  handle_post_type( x)
 
  strip_http_type( x)

  rewrite_index_html( x) 


 #   # rewrite rule / to web root,
#   # might be better to let the static file server handle this stuff...
#   matches = /GET \/(.*)/.match(x[:request])
#   if matches and matches.captures.length == 1
#     x[:request] = "GET /root/#{matches.captures[0]}" 
#     #puts "rewriting to #{x[:request]}" 
#   end
# 
  
#   # static resource
#   matches = /GET (.*\.txt|.*\.html|.*\.css|.*\.js|.*\.jpeg|.*\.png)$/.match(x[:request])
#   if matches and matches.captures.length == 1
#     # resource = matches.captures[ 0]
#     result = fileContent.serve_file( x[:request] )
#     Helper.write_response( result.headers, result.io_content, socket )
#     return true
#   end
# 

  static_resource( x, fileContent )

#   # change name get_data or get series etc
#   if /GET \/get_series.json$/.match(x[:request])
#       result = model.get_series()
#       Helper.write_response( result.headers, result.io_content, socket )
#   end
# 

  get_series( x, model )


#   if /GET \/get_id.json$/.match(x[:request])
#       content_ = model.get_id()  
#       content_io = StringIO.new( content_, "r")
#       Helper.write_json( content_io, socket )
#       return true
#   end

  get_id( x, model )


  send_response( x )



#   if /GET \/get_time.json$/.match(x[:request])
#       content_ = model.get_time()  
#       content_io = StringIO.new( content_, "r")
#       Helper.write_json( content_io, socket )
#       return true
#   end
# 

  

  # head, post, etc. 
#  Helper.write_hello_message( m, socket )

  true

end



model = Model::EventProcessor.new()

server = Server::Processor.new() 


fileContent = Static::FileContent.new( "#{Dir.pwd}/static" )





# server.start_ssl(1443) do |socket|
# 
#   application( socket, model)
# end
# 

server.start(  2345 ) do |socket|   

  application( socket, model, fileContent)

end




conn = PG::Connection.open(:dbname => 'prod', :user => 'meteo', :password => 'meteo' )

f = proc { |a,b,c,d| model.process_event(a,b,c,d) }


id = -1 

# start processing events at current less 500
id = conn.exec_params( "select max(id) - 2000 as max_id from events" )[0]['max_id']

puts "starting events at #{id}" 

id = Model.process_events( conn, id, f )

puts "finished processing historic events, id now #{id}"

Model.process_current_events( conn, id, f )

#puts model.get()

# should rename to wait
server.run() 

