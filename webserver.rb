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

          # puts keys
          break if code.call( socket ).nil?

#         # i think we get a broken pipe if we can't read anything
#         rescue Errno::EPIPE 
#           $stderr.puts "*** EPIPE "
#           socket.close
#           break;
# 
#         rescue IOError => e
#           $stderr.puts "*** IOError #{e.message} "
#           socket.close
#           break
# 
#         #rescue
#           # Exception Broken pipe is normal when client disconnects - eg. when 302 disconnect 
# 
          
        rescue => e
          puts "Error during processing: #{$!}"
          puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"

          $stderr.puts "Unknown Exception #{$!}"
          $stderr.puts "dropping conection"
          # call close, just in case
          break
        end
      end

      # the close should only be in one place
      $stderr.puts "# really closing scoket "
      socket.close

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

