
# ok, we want to try to serve files. 
# which means accessing file system - and cleaning path

require './server'
require './static'
require './helper'
require './calc_series'

server = Server::Processor.new() 

# Ok aparently ruby blocks can reference their enclosing scope!
# how are we going to pass a reference into into the processing block...
model = Model::EventProcessor.new()


server.start_ssl(1443) do |socket|

  m = Helper.decode_request( socket) 
  request = m['request']

  # if the connection was closed by remote
  if request.nil?
    $stderr.puts "eof on https"
    next nil
  end


  # so we have to do some message cracking
  #puts "-------------"
  puts "request is #{ request }"


  # determine http request type
  # we ought to do a bit more here,
  # and strip it.
  matches = /(GET .*)\s(HTTP.*)/.match(request)
  if matches and matches.captures.length == 2
    request = matches.captures[0] 
    #puts "rewriting to #{request}" 
  else
    Helper.write_hello_message( m, socket )
    next true
  end

  # rewrite top level / to index.html
  if matches = /GET \/$/.match(request)
    request = "GET /index.html" 
    #puts "rewriting to #{request}" 
  end

  # rewrite rule / to web root,
  # might be better to let the static file server handle this stuff...
  matches = /GET \/(.*)/.match(request)
  if matches and matches.captures.length == 1
    request = "GET /root/#{matches.captures[0]}" 
    #puts "rewriting to #{request}" 
  end

  
  # static resource
  matches = /GET (.*\.txt|.*\.html|.*\.css|.*\.js|.*\.jpeg|.*\.png)$/.match(request)
  if matches and matches.captures.length == 1
    resource = matches.captures[ 0]
  
    # puts "whoot matched #{resource}"
    # make sure it's there
    m['request'] = request

    # ok, we're getting null messages from firefox ?
    Static.serve_file( m, socket)
    next true
  end


  # change name get_data or get series etc
  if /GET \/root\/out.json$/.match(request)
      content = model.get()  
      Helper.write_json( content, socket )
      next true
  end


  if /GET \/root\/get_time.json$/.match(request)
      content = model.get_time()  
      Helper.write_json( content, socket )
      next true
  end

  if /GET \/root\/get_id.json$/.match(request)
      content = model.get_id()  
      Helper.write_json( content, socket )
      next true
  end




  # head, post, etc. 
  Helper.write_hello_message( m, socket )
  

  true
end


server.start(  2345 ) do |socket|   

    request = Helper.decode_request( socket) 

    # if the connection was closed by remote
    if request['request'].nil?
      $stderr.puts "eof on http "
      next nil
    end

    Helper.write_redirect_message( request, socket )

    true
end



# ok, we want to pass the model to the server
# it's not just an event processor



conn = PG::Connection.open(:dbname => 'prod', :user => 'meteo', :password => 'meteo' )

f = proc { |a,b,c,d| model.process_event(a,b,c,d) }



id = -1 

# start processing events at current less 500
id = conn.exec_params( "select max(id) - 2000 as max_id from events" )[0]['max_id']

puts "starting events at #{id}" 

id = Model.process_events( conn, id, f )

puts "done processing historic - id #{id}"

Model.process_current_events( conn, id, f )

#puts model.get()

# should rename to wait
server.run() 

