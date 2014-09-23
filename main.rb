
# ok, we want to try to serve files. 
# which means accessing file system - and cleaning path

require './webserver'
require './static'

threads = []

Webserver.start_https( threads, 1443) do |keys, socket|

  #request = keys['request']
  Static.serve_file( keys, socket)

#   request = keys['request']
#   puts "request #{request}"
# 
# 
#   path = Webserver.requested_file( request)
# 
#   puts "path is #{path}"
# 
#   Webserver.write_hello_message( keys, socket )
end

Webserver.start_http( threads , 2345 ) do |keys,socket|   
  Webserver.write_redirect_message( keys, socket )
end


# wait for threads to finish
threads.each() do |t|
  t.join()
end


