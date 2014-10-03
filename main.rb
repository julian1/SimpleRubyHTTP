
require './server'
require './static'
require './helper'
require './calc_series'


# chain together transforms...


# Ok aparently ruby blocks can reference their enclosing scope!
# how are we going to pass a reference into into the processing block...


def decode_request( x)

  puts "---------------"

  # OK. This decode should be part of the chain....
  #Helper.decode_request( x ) 
    socket = x[:socket]
    x[:request] = socket.gets
    while line = socket.gets("\r\n")  # this blocks, because there's nothing more to read after the first line.
                                      # i think this is correct behavior
      break if line == "\r\n"
      s = line.split(':')
      x[:request_headers][ s[0].strip] = s[1].strip 
    end

end


def log_request( x)
  puts "request '#{ x[:request].strip }'"
  puts "request_headers #{ x[:request_headers] }"
end


def handle_post_type( x)
  # should we inject the socket straight in here ?
  # it makes instantiating the graph harder...
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
    abort('here777777')
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


def serve_static_resource( x, fileContent)
  # Don't think we have to handle 404 here.
  matches = /GET (.*\.txt|.*\.html|.*\.css|.*\.js|.*\.jpeg|.*\.png|.*\.ico)$/.match(x[:request])
  if matches and matches.captures.length == 1
    fileContent.serve_file( x )
  end
end


def serve_model_resource( x, model )
  # can be separate filters or the same
  if /GET \/get_series.json$/.match(x[:request])
      model.get_series( x)
  end
  if /GET \/get_id.json$/.match(x[:request])
      model.get_id( x )
  end

end




def do_cookie_stuff( x)
  begin
    cookie = x[:request_headers]['Cookie'].to_i + 1
  rescue
    cookie = 0
  end

  puts "***** COOKIE  #{ cookie }"
 
  x[:response_headers]['Set-Cookie:'] = "#{cookie}\r\n"

end



def everything_else( x)

  if /GET.*$/.match(x[:request]) \
    && x[:response].nil?

    x[:response] = "HTTP/1.1 404 Not Found\r\n"
    x[:response_headers]['Content-Type:'] = "text/plain\r\n"
    x[:body] = StringIO.new( <<-EOF
File not found!
      EOF
      )
  end

end


def send_response( x)
  # note that we could pass in the socket here,
  # rather than pass it about everywhere....
  # issue is that if it's a post, then we want to read ...
  # send response expects this ...
  Helper.write_response( x )
end

def log_response( x)
  puts "response '#{ x[:response].strip }'"
  puts "response_headers #{ x[:response_headers] }"
end





def application( socket, model, fileContent)

  # we can still use functions t
  x = {
    :request => nil,
    :request_headers => {},
    :socket => socket,
    :response => nil,
    :response_headers => {},
    :body => nil
  }

  decode_request( x) 

  log_request( x)

  # if the connection was closed by remote
  if x[:request].nil?
    $stderr.puts "eof on https"
    return nil
  end


  handle_post_type( x)
 
  strip_http_type( x)


  # main stuff here
  rewrite_index_html( x) 

  serve_static_resource( x, fileContent )

  serve_model_resource( x, model )


  do_cookie_stuff( x)

  everything_else( x)

  send_response( x )

  log_response( x)

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

