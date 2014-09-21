#require 'socket' # Provides TCPServer and TCPSocket classes
#require 'openssl' 



require "socket"
require "openssl"
require "thread"

listeningPort = 1443 #Integer(ARGV[0])

server = TCPServer.new(listeningPort)
sslContext = OpenSSL::SSL::SSLContext.new
#sslContext.cert = OpenSSL::X509::Certificate.new(File.open("cert.pem"))
#sslContext.key = OpenSSL::PKey::RSA.new(File.open("priv.pem"))
sslContext.cert = OpenSSL::X509::Certificate.new(File.open("server.crt"))
sslContext.key = OpenSSL::PKey::RSA.new(File.open("server.key"))
sslServer = OpenSSL::SSL::SSLServer.new(server, sslContext)

puts "Listening on port #{listeningPort}"

loop do
  socket = sslServer.accept
  Thread.new {
    begin

      # what's the terminator of the message...
      # should parse this into key value pairs... 
      # Decode message
      puts "--------------------"
      i = 0
      keys = {}
      while line = socket .gets# Read lines from socket
        break if line == "\r\n"
        if i == 0 
          keys['request'] = line.strip
        else 
        s = line.split(':')
        keys[ s[0].strip] = s[1].strip 
        end
        i += 1
      end

      puts keys
      puts "here2"

  response = "Hello World!\n"

  # We need to include the Content-Type and Content-Length headers
  # to let the client know the size and type of data
  # contained in the response. Note that HTTP is whitespace
  # sensitive, and expects each header line to end with CRLF (i.e. "\r\n")
  socket.print "HTTP/1.1 200 OK\r\n" +
               "Content-Type: text/plain\r\n" +
               "Content-Length: #{response.bytesize}\r\n" +
                "Set-Cookie: name=whoot\r\n" +
               "Connection: close\r\n"

  # Print a blank line to separate the header from the response body,
  # as required by the protocol.
  socket.print "\r\n"

  # Print the actual response body, which is just "Hello World!\n"
  socket.print response

  # Close the socket, terminating the connection
  # do we really need to do this ??
  socket.close



#       while (lineIn = connection.gets)
#         lineIn = lineIn.chomp
#         $stdout.puts "=> " + lineIn
#         lineOut = "You said: " + lineIn
#         $stdout.puts "<= " + lineOut
#         connection.puts lineOut
#       end
    rescue
      $stderr.puts $!
    end
  }
end

