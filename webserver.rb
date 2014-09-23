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
require "uri"
#require "dir"


module Webserver

def Webserver.decode_message( socket )
  keys = {}
  # probably should structure this differenly...
  # if it's a post, then we will want to slurp a lot more...
  keys['request'] = socket.gets
  while line = socket.gets
    break if line == "\r\n"
    s = line.split(':')
    keys[ s[0].strip] = s[1].strip 
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

  cookie = 0
  cookie = ignore_exception {  keys[ 'Cookie'].to_i + 1 }
  puts "setting cookie to #{cookie}"

  response = "Hello World!\n"

  # We need to include the Content-Type and Content-Length headers
  # to let the client know the size and type of data
  # contained in the response. Note that HTTP is whitespace
  # sensitive, and expects each header line to end with CRLF (i.e. "\r\n")

  # In HTTP 1.1, all connections are considered persistent unless declared otherwise.
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
    <p>The document has moved</a>.</p>
    <hr>
    <address>Apache Server at imos.aodn.org.au Port 80</address>
    </body></html>
  EOS
 
  socket.print "HTTP/1.1 302 Found\r\n" + 
    "Date: Sun, 21 Sep 2014 09:02:16 GMT\r\n" + 
    "Server: Apache\r\n" +
    "Location: https://localhost:1443\r\n" + 
    "Vary: Accept-Encoding\r\n" + 
    "Content-Length: 282\r\n" +
    "Content-Type: text/html; charset=iso-8859-1\r\n" +
    "\r\n"

  # Print the actual response body, which is just "Hello World!\n"
  socket.print response
end


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

          keys = decode_message( socket) 
          # puts keys
          code.call( keys, socket )

        # i think we get a broken pipe if we can't read anything
        rescue Errno::EPIPE 
          $stderr.puts "*** EPIPE "
          socket.close
          break;

        rescue IOError => e
          $stderr.puts "*** IOError #{e.message} "
          socket.close
          break

        rescue
          # Exception Broken pipe is normal when client disconnects - eg. when 302 disconnect 
          $stderr.puts "Unknown Exception #{$!}"
          $stderr.puts "dropping conection"
          # call close, just in case
          #socket.close
          break
        end
      end
    }
  end
end


def Webserver.start_https( threads, listeningPort, &code)
  threads << Thread.new {
    begin
      server = TCPServer.new(listeningPort)
      sslContext = OpenSSL::SSL::SSLContext.new
      sslContext.cert = OpenSSL::X509::Certificate.new(File.open("certs/server.crt"))
      sslContext.key = OpenSSL::PKey::RSA.new(File.open("certs/server.key"))
      sslServer = OpenSSL::SSL::SSLServer.new(server, sslContext)

      puts "https listening on port #{listeningPort}"
      process_accept( sslServer, &code)
    rescue
      $stderr.puts "https exception #{$!}"
    end
  }
end


def Webserver.start_http( threads, listeningPort, &code)
  threads << Thread.new {
    begin
      server = TCPServer.new('localhost', listeningPort)

      puts "http listening on port #{listeningPort}"
      process_accept( server,  &code)
    rescue
      $stderr.puts "http exception #{$!}"
    end
  }
end

end

