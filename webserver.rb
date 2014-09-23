#!/usr/bin/ruby

# Simple webserver example, 
# supports connection keep alive, cookies, https and redirection 
# need cache control
# websockets,


# there's an issue - if try http on 1443 - it goes into unknown state
# https://localhost:1443/

# wget --no-check-certificate 'http://localhost:2345'

#require 'socket' # Provides TCPServer and TCPSocket classes
#require 'openssl' 



require "socket"
require "openssl"
require "thread"


module Webserver

def Webserver.decode_message( socket )
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

def Webserver.ignore_exception
   begin
     yield  
   rescue Exception
  end
end

def Webserver.write_hello_message( keys, socket )

      puts "write_hello keys"
      puts keys

      cookie = 0
      cookie = ignore_exception {  keys[ 'Cookie'].to_i + 1 }

      puts "setting cookie to #{cookie}"

      response = "- Hello World!\n"

      # We need to include the Content-Type and Content-Length headers
      # to let the client know the size and type of data
      # contained in the response. Note that HTTP is whitespace
      # sensitive, and expects each header line to end with CRLF (i.e. "\r\n")

    # In HTTP 1.1, all connections are considered persistent unless declared otherwise.

#                   "Connection: close\r\n"

      socket.print "HTTP/1.1 200 OK\r\n" +
                   "Content-Type: text/plain\r\n" +
                   "Content-Length: #{response.bytesize}\r\n" +
                    "Set-Cookie: #{cookie}\r\n" +
                    "Connection: Keep-Alive\r\n" +
                    "\r\n"

      # Print the actual response body, which is just "Hello World!\n"
      socket.print response
end


def Webserver.write_redirect_message( keys, socket )

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
 
#    "Location: https://imos.aodn.org.au/imos123\r\n" + 

  socket.print "HTTP/1.1 302 Found\r\n" + 
    "Date: Sun, 21 Sep 2014 09:02:16 GMT\r\n" + 
    "Server: Apache\r\n" +
    "Location: https://localhost:1443\r\n" + 
    "Vary: Accept-Encoding\r\n" + 
    "Content-Length: 282\r\n" +
    "Content-Type: text/html; charset=iso-8859-1\r\n" +
    "\r\n"

#    https://localhost:1443/

      # Print the actual response body, which is just "Hello World!\n"
      socket.print response

end


# it would be nice to be able to process both ssl and non ssl with the same 
# decode loop 

## ugh.. how do we do this we want to pass a block ...

def Webserver.process_accept( server, &code )
  loop do
    socket = server.accept

    puts "--------------------"
    puts "** new connection"

      # if we don't spawn the thread then we get a broken pipe which is weird
    Thread.new {
      loop do
      begin
  
        # we can decode the keys in here, ? we should do this
        # so we can abstract session management

        # what's the terminator of the message...
        # should parse this into key value pairs... 
        # Decode message
        keys = decode_message( socket) 
        # puts keys

        code.call( keys, socket )

#        write_redirect_message( socket )
        #write_hello_message( socket )

        # Close the socket, terminating the connection
        # do we really need to do this ??

#         puts "before socket close"
#         socket.close
#         puts "after socket close"
# 
      rescue
        # Exception Broken pipe is normal when client disconnects - eg. when 302 disconnect 
        $stderr.puts "Exception #{$!}"
        $stderr.puts "dropping conection"
        # call close, just in case
        socket.close
        break
      end
      end
    
    }
  end
end




# we want to abstract the starting of the servers ...
def Webserver.start_https( threads, listeningPort)
  threads << Thread.new {
    begin
      # listeningPort = 1443 #Integer(ARGV[0])

      server = TCPServer.new(listeningPort)
      sslContext = OpenSSL::SSL::SSLContext.new
      #sslContext.cert = OpenSSL::X509::Certificate.new(File.open("cert.pem"))
      #sslContext.key = OpenSSL::PKey::RSA.new(File.open("priv.pem"))
      sslContext.cert = OpenSSL::X509::Certificate.new(File.open("server.crt"))
      sslContext.key = OpenSSL::PKey::RSA.new(File.open("server.key"))
      sslServer = OpenSSL::SSL::SSLServer.new(server, sslContext)

      puts "https listening on port #{listeningPort}"

      process_accept sslServer do |keys, socket| 
        write_hello_message( keys, socket )
          # write_redirect_message( socket )
        end
    rescue
      $stderr.puts "https exception #{$!}"
    end
  }
end

# so we want to be able to abstract this a bit...

# ok, it works, but doesn't terminate cleanly if do ssl on 2345 


def Webserver.start_http( threads, listeningPort)
  threads << Thread.new {
    begin
      # listeningPort = 2345 #Integer(ARGV[0])
      server2 = TCPServer.new('localhost', listeningPort)
      puts "http listening on port #{listeningPort}"
      process_accept server2 do  |keys, socket| 

          # write_hello_message( keys, socket )
          write_redirect_message( keys, socket )
        end
    rescue
      $stderr.puts "http exception #{$!}"
    end
  }
end


end


