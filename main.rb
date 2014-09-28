
# ok, we want to try to serve files. 
# which means accessing file system - and cleaning path

require './webserver'
require './static'
require './helper'

threads = []

Webserver.start_https( threads, 1443) do | socket|
  #Webserver.write_hello_message( keys, socket )

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


Webserver.start_http( threads , 2345 ) do |socket|   

    keys = Helper.decode_message( socket) 

    # if the connection was closed by remote
    if keys['request'].nil?
      $stderr.puts "eof on http "
      next nil
    end

    Helper.write_redirect_message( keys, socket )

    true
end


# wait for threads to finish
threads.each() do |t|
  t.join()
end


