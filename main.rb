require 'socket' # Provides TCPServer and TCPSocket classes


def escape(s)
  s.inspect[1..-2]
end

# Initialize a TCPServer object that will listen
# on localhost:2345 for incoming connections.
server = TCPServer.new('localhost', 2345)

puts "listening on 2345"

count = 0
# loop infinitely, processing one incoming
# connection at a time.
loop do

  # Wait until a client connects, then return a TCPSocket
  # that can be used in a similar fashion to other Ruby
  # I/O objects. (In fact, TCPSocket is a subclass of IO.)
  socket = server.accept


  # what's the terminator of the message...
  # should parse this into key value pairs... 
  puts "--------------------"
  lines = []
  while line = socket.gets# Read lines from socket
    puts escape(line) #line.length
    break if line == "\r\n"
    lines << line         
  end

  puts "here2"

  #puts lines.join("")
  # Read the first line of the request (the Request-Line)
  request = line[0]#socket.gets

# Log the request to the console for debugging
  STDERR.puts request

  
  response = "Hello World!\n"

  # We need to include the Content-Type and Content-Length headers
  # to let the client know the size and type of data
  # contained in the response. Note that HTTP is whitespace
  # sensitive, and expects each header line to end with CRLF (i.e. "\r\n")
  socket.print "HTTP/1.1 200 OK\r\n" +
               "Content-Type: text/plain\r\n" +
               "Content-Length: #{response.bytesize}\r\n" +
                "Set-Cookie: name=#{count}\r\n" +
               "Connection: close\r\n"

  # Print a blank line to separate the header from the response body,
  # as required by the protocol.
  socket.print "\r\n"

  # Print the actual response body, which is just "Hello World!\n"
  socket.print response

  # Close the socket, terminating the connection
  # do we really need to do this ??
  socket.close

  count+= 1
end
