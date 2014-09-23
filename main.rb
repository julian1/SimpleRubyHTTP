

require './webserver'

threads = []

Webserver.start_https( threads, 1443) do |keys, socket|
  # puts keys
  Webserver.write_hello_message( keys, socket )
end

Webserver.start_http( threads , 2345 ) do |keys,socket|   
  Webserver.write_redirect_message( keys, socket )
end


# wait for threads to finish
threads.each() do |t|
  t.join()
end


