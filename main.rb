

require './webserver'

threads = []

Webserver.start_https( threads, 1443);

Webserver.start_http( threads , 2345 ) do |keys,socket|   
  Webserver.write_redirect_message( keys, socket )
end


# wait for threads to finish
threads.each() do |t|
  t.join()
end

# fuck ruby is complicated with it's argument passing.

