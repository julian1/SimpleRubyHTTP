

require './webserver'

threads = []

Webserver.start_https( threads, 1443)
Webserver.start_http( threads , 2345)

# wait for threads to finish
threads.each() do |t|
  t.join()
end



