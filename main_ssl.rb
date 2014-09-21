#require 'socket' # Provides TCPServer and TCPSocket classes
#require 'openssl' 



require "socket"
require "openssl"
require "thread"



def decode_message( socket )
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
  keys
end


def write_hello_message( socket )
      response = "- Hello World!\n"

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
end


def write_redirect_message( socket )

  response = <<-EOS  
    <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
    <html><head>
    <title>302 Found</title>
    </head><body>
    <h1>Found</h1>
    <p>The document has moved <a href="https://imos.aodn.org.au/imos123">here</a>.</p>
    <hr>
    <address>Apache Server at imos.aodn.org.au Port 80</address>
    </body></html>
  EOS
 
  socket.print "HTTP/1.1 302 Found\r\n" + 
  "Date: Sun, 21 Sep 2014 09:02:16 GMT\r\n" + 
  "Server: Apache\r\n" +
  "Location: https://imos.aodn.org.au/imos123\r\n" + 
  "Vary: Accept-Encoding\r\n" + 
  "Content-Length: 282\r\n" +
  "Content-Type: text/html; charset=iso-8859-1\r\n"
 
    socket.print "\r\n"

      # Print the actual response body, which is just "Hello World!\n"
      socket.print response

end


# it would be nice to be able to process both ssl and non ssl with the same 
# decode loop 

def process_accept( server )
  loop do
    socket = server.accept
      # if we don't spawn the thread then we get a broken pipe which is weird
    Thread.new {
      begin

        # what's the terminator of the message...
        # should parse this into key value pairs... 
        # Decode message
        puts "--------------------"
        keys = decode_message( socket) 
        puts keys

        write_redirect_message( socket )
        #write_hello_message( socket )

        # Close the socket, terminating the connection
        # do we really need to do this ??
        socket.close

      rescue
        $stderr.puts $!
      end
    }
  end
end



threads = []



threads << Thread.new {
  begin
    listeningPort = 1443 #Integer(ARGV[0])

    server = TCPServer.new(listeningPort)
    sslContext = OpenSSL::SSL::SSLContext.new
    #sslContext.cert = OpenSSL::X509::Certificate.new(File.open("cert.pem"))
    #sslContext.key = OpenSSL::PKey::RSA.new(File.open("priv.pem"))
    sslContext.cert = OpenSSL::X509::Certificate.new(File.open("server.crt"))
    sslContext.key = OpenSSL::PKey::RSA.new(File.open("server.key"))
    sslServer = OpenSSL::SSL::SSLServer.new(server, sslContext)

    puts "Listening on port #{listeningPort}"

    process_accept( sslServer )
  rescue
    $stderr.puts $!
  end
}

# ok, it works, but doesn't terminate cleanly if do ssl on 2345 

threads << Thread.new {
  begin
    listeningPort = 2345 #Integer(ARGV[0])
    server2 = TCPServer.new('localhost', listeningPort)
    puts "Listening on port #{listeningPort}"
    process_accept( server2 )
  rescue
    $stderr.puts $!
  end
}





# wait for threads to finish
threads.each() do |t|
  t.join()
end


