
# ok, we want to try to serve files. 
# which means accessing file system - and cleaning path

require './server'
require './static'
require './helper'

server = Server::Processor.new() 


server.start_ssl(  1443) do | socket|
  #Server.write_hello_message( keys, socket )

    keys = Helper.decode_message( socket) 

    # if the connection was closed by remote
    if keys['request'].nil?
      $stderr.puts "eof on https"
      next nil
    end


  #
  # ok, we're getting null messages from firefox ?
  Static.serve_file( keys, socket)

  true
end


server.start(  2345 ) do |socket|   

    keys = Helper.decode_message( socket) 

    # if the connection was closed by remote
    if keys['request'].nil?
      $stderr.puts "eof on http "
      next nil
    end

    Helper.write_redirect_message( keys, socket )

    true
end

server.run() 

