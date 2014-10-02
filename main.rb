
require './server'
require './static'
require './helper'
require './calc_series'



def application( socket, model, fileContent)

  m = Helper.decode_request( socket) 

  puts m

  request = m['request']

  # if the connection was closed by remote
  if request.nil?
    $stderr.puts "eof on https"
    return nil
  end


  # so we have to do some message cracking
  #puts "-------------"
  puts "request is #{ request }"



  if /POST .*$/.match(request)
      puts "************ got post !!! ***********"
      puts m

      # we must read content , otherwise it gets muddled up
      # it gets read at the next http request, when connection
      # is keep alive. 

      Helper.write_hello_message( m, socket )
      return true
  end




  # determine http request type
  # we ought to do a bit more here,
  # and strip it.
  matches = /(GET .*)\s(HTTP.*)/.match(request)
  if matches and matches.captures.length == 2
    request = matches.captures[0] 
    #puts "rewriting to #{request}" 
  else
    Helper.write_hello_message( m, socket )
    return true
  end

  # rewrite top level / to index.html
  if matches = /GET \/$/.match(request)
    request = "GET /index.html" 
    #puts "rewriting to #{request}" 
  end

#   # rewrite rule / to web root,
#   # might be better to let the static file server handle this stuff...
#   matches = /GET \/(.*)/.match(request)
#   if matches and matches.captures.length == 1
#     request = "GET /root/#{matches.captures[0]}" 
#     #puts "rewriting to #{request}" 
#   end
# 
  
  # static resource
  matches = /GET (.*\.txt|.*\.html|.*\.css|.*\.js|.*\.jpeg|.*\.png)$/.match(request)
  if matches and matches.captures.length == 1
    # resource = matches.captures[ 0]
    result = fileContent.serve_file( request )
    Helper.write_response( result.headers, result.io_content, socket )
    return true
  end



  # change name get_data or get series etc
  if /GET \/get_series.json$/.match(request)
      result = model.get_series()
      Helper.write_response( result.headers, result.io_content, socket )
  end


#   if /GET \/get_time.json$/.match(request)
#       content_ = model.get_time()  
#       content_io = StringIO.new( content_, "r")
#       Helper.write_json( content_io, socket )
#       return true
#   end
# 
  if /GET \/get_id.json$/.match(request)
      content_ = model.get_id()  
      content_io = StringIO.new( content_, "r")
      Helper.write_json( content_io, socket )
      return true
  end


  

  # head, post, etc. 
  Helper.write_hello_message( m, socket )

  true

end




server = Server::Processor.new() 

# Ok aparently ruby blocks can reference their enclosing scope!
# how are we going to pass a reference into into the processing block...
model = Model::EventProcessor.new()


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

