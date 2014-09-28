#!/usr/bin/ruby

require "socket"
require "openssl"
require "thread"



module Server

  class Processor

    def initialize()
      @threads = []
    end 

    def process_accept( server, &code )
      loop do
        socket = server.accept

        $stderr.puts "** new connection"

        # if we don't spawn the thread then we get a broken pipe which is weird
        Thread.new {
          loop do
            begin

              # call handler block
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
            rescue => e
              $stderr.puts "Error during processing: #{$!}"
              $stderr.puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
              $stderr.puts "Unknown Exception #{$!}"
              break
            end
          end

          # the close should only be in one place
          $stderr.puts "** close connection"
          socket.close

        }
      end
    end


    def start_ssl(  listeningPort, &code)
        @threads << Thread.new {
        begin
          server = TCPServer.new(listeningPort)
          sslContext = OpenSSL::SSL::SSLContext.new
          sslContext.cert = OpenSSL::X509::Certificate.new(File.open("certs/server.crt"))
          sslContext.key = OpenSSL::PKey::RSA.new(File.open("certs/server.key"))
          sslServer = OpenSSL::SSL::SSLServer.new(server, sslContext)

          $stderr.puts "https listening on port #{listeningPort}"
          process_accept( sslServer, &code)
        rescue
          $stderr.puts "ssl socket exception #{$!}"
        end
      }
    end


    def start(  listeningPort, &code)
      @threads << Thread.new {
        begin
          server = TCPServer.new('localhost', listeningPort)

          $stderr.puts "http listening on port #{listeningPort}"
          process_accept( server,  &code)
        rescue
          $stderr.puts "socket exception #{$!}"
        end
      }
    end

    def run()
      # wait for threads to finish
      @threads.each() do |t|
        t.join()
      end
    end
  end

end

