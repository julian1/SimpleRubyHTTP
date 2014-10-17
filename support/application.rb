

class Application

  def initialize( log, controllers )
    @log = log
    @controllers = controllers
    @log.warn("Application started")
  end



  def process_request_new( conn, data)

    #puts "application received #{data}" 
    #puts "-------------"

    # init message structure
    x = {
      :conn => conn,
      :request => nil,
      :request_headers => {},
   #   :socket => socket,
      :response => nil,
      :response_headers => {},
      :body => nil
    }
    # ok, we want to try to load the data up into a string io
    # and then parse it. 

    ss = StringIO.new( data, "r")

    x[:request] = ss.gets
    while line = ss.gets("\r\n")
      break if line == "\r\n"
      # key,val
      s = line.split(':')
      x[:request_headers][ s[0].strip] = s[1].strip
    end

    #puts  "#{x[:request_headers]}"
    #conn.send_data("helo\n")


    @controllers.each do |controller|
      controller.action(x)
    end

	end

# 
#   def process_request( socket)
# 
#     # init message structure
#     x = {
#       :request => nil,
#       :request_headers => {},
#       :socket => socket,
#       :response => nil,
#       :response_headers => {},
#       :body => nil
#     }
# 
#     decode_request( x)
# 
#     # note, we aren't logging nil which generally is close
# 
#     # no request, indicating connection close by remote
#     # we don't actually need to log this
#     if x[:request].nil?
#       return nil
#     end
# 
#     @controllers.each do |controller|
#       controller.action(x)
#     end
# 
#     true
#   end
# 
# 
#   def decode_request( x)
#     # TODO needs to separate multiple returned cookies into an array
#     socket = x[:socket]
#     x[:request] = socket.gets
#     while line = socket.gets("\r\n")
#       break if line == "\r\n"
#       s = line.split(':')
#       x[:request_headers][ s[0].strip] = s[1].strip
#     end
#   end

end


