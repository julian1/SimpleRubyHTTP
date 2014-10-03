
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
  puts "request '#{ x[:request] ? x[:request].strip : "nil"  }'"
  puts "request_headers #{ x[:request_headers] }"
end


def handle_post_request( x)
  # should we inject the socket straight in here ?
  # it makes instantiating the graph harder...
  if /^POST .*$/.match(x[:request])
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


def strip_http_version( x)
  # eases subsequent processing
  # should do this on other types also ?
  matches = /^(GET .*)\s(HTTP.*)/.match(x[:request])
  if matches and matches.captures.length == 2
    x[:request] = matches.captures[0] 
  end
end 



def rewrite_index_get( x)
  # rewrite top level / to index.html
  if matches = /^GET \/$/.match(x[:request])
    x[:request] = "GET /index.html" 
    #puts "rewriting to #{x[:request]}" 
  end
end


def serve_static_resource( x, fileContent)

  matches = /^GET (.*\.txt|.*\.html|.*\.css|.*\.js|.*\.jpeg|.*\.png|.*\.ico)$/.match(x[:request])
  if matches and matches.captures.length == 1

    # Do Etag stuff around here,

    fileContent.serve_file( x )
  end
end


def serve_model_resource( x, model )
  # can be separate filters or the same


  if /^GET \/get_series.json$/.match(x[:request])
      model.get_series( x)
  end

  if /^GET \/get_id.json$/.match(x[:request])
      model.get_id( x )
  end

end




def do_cookie_stuff( x)
  begin
    cookie = x[:request_headers]['Cookie'].to_i + 1
  rescue
    cookie = 0
  end
 
  x[:response_headers]['Set-Cookie'] = "#{cookie}"
end


# we ought to be able to hanlde 403 message and egg, by just doing it 
# before normal resource
# processing



def do_cache_control( x)
  # this may need to be combined with other resource handling, and egg stuff.
  # caache constrol should be hanlded externally to this.
  # max-age=0
  
  # it's possible this might vary depending on the user-agent 

  unless x[:response_headers]['Cache-Control']
    x[:response_headers]['Cache-Control']= "private"
  end

  # headers['Cache-Control:']= "private,max-age=100000"
  # firefox will send 'If-None-Match' nicely. dont have to set cache-control flags 
end


def catch_all( x)

  # resource not found
  if x[:response].nil?

    puts "**** catchall #{ x[:request]} "

    # this is matching AGETA which is not what we want
    if /^GET.*$/.match(x[:request])
      # GET request
      x[:response] = "HTTP/1.1 404 Not Found"
      x[:response_headers]['Content-Type'] = "text/plain"
      x[:body] = StringIO.new( <<-EOF
File not found!
        EOF
        )
    else
      # catch all, for non-implemented or badly formed request
      x[:response] = "HTTP/1.1 400 Bad Request"
      x[:response_headers]['Content-Type'] = "text/plain"
      x[:body] = StringIO.new( <<-EOF
Your browser sent a request that this server could not understand
        EOF
        )
    end
  end
end


def send_response( x)
  # note that we could pass in the socket here,
  # rather than pass it about everywhere....
  # issue is that if it's a post, then we want to read ...
  # send response expects this ...

  # we can have a few options about how we send the response.
  # send chunked, etc.
  # either separate methods, or something else ...

  Helper.write_response( x )
end


def log_response( x)
  puts "response '#{ x[:response].strip }'"
  puts "response_headers #{ x[:response_headers] }"
end





def process_request( socket, model, fileContent)

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
    return nil
  end


  handle_post_request( x)
 
  strip_http_version( x)


  # main stuff here
  rewrite_index_get( x) 

  serve_static_resource( x, fileContent )

  serve_model_resource( x, model )


  do_cookie_stuff( x)

  do_cache_control( x)

  catch_all( x)

  send_response( x )

  log_response( x)

  true

end



model = Model::EventProcessor.new()

server = Server::Processor.new() 


fileContent = Static::FileContent.new( "#{Dir.pwd}/static" )





server.start_ssl(1443) do |socket|
  process_request( socket, model, fileContent)
end


server.start(8000) do |socket|   
  process_request( socket, model, fileContent)
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

