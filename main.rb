
require './server'
require './static'
require './helper'
require './calc_series'


# chain together transforms...


# Ok aparently ruby blocks can reference their enclosing scope!
# how are we going to pass a reference into into the processing block...

def log_request( x)
  puts "request '#{ x[:request] }'"
  puts "request_headers #{ x[:request_headers] }"
end


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


def static_resource( x, fileContent)
  # Don't think we have to handle 404 here.
  matches = /GET (.*\.txt|.*\.html|.*\.css|.*\.js|.*\.jpeg|.*\.png|.*\.ico)$/.match(x[:request])
  if matches and matches.captures.length == 1
    fileContent.serve_file( x )
  end
end


def get_series( x, model )
  if /GET \/get_series.json$/.match(x[:request])
      model.get_series( x)
  end
end


def get_id( x, model )
  if /GET \/get_id.json$/.match(x[:request])
      model.get_id( x )
  end
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





def application( socket, model, fileContent)

  # OK. This decode should be part of the chain....
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

  log_request( x)

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

  static_resource( x, fileContent )

  get_series( x, model )

  get_id( x, model )

  everything_else( x)

  send_response( x )

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

