#!/usr/bin/ruby

require "socket"
require "openssl"
require "thread"
require 'logger'


module Server

  class Processor

    def initialize( log)
      @log = log
      @threads = []
    end

    def process_accept( server, &code )
      loop do
        socket = server.accept

        ip = socket.peeraddr[3] 
        @log.info("new connection #{ip}")

        # if we don't spawn the thread then we get a broken pipe which is weird
        Thread.new {
          loop do
            begin

              # call handler block
              break if code.call( socket ).nil?

              # # i think we get a broken pipe if we can't read anything
              # rescue Errno::EPIPE
              # $stderr.puts "*** EPIPE "
              # socket.close
              # break;
              #
              # rescue IOError => e
              #   $stderr.puts "*** IOError #{e.message} "
              #   socket.close
              #   break

            rescue => e
              @log.warn( "Error during processing: #{$!}" )
              @log.warn( "Backtrace:\n\t#{e.backtrace.join("\n\t")}" )
              @log.warn( "Unknown Exception #{$!}" )
              break
            end
          end

          # the close should only be in one place
          @log.info( "close connection")
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

          @log.info( "https listening on port #{listeningPort}")
          process_accept( sslServer, &code)
        rescue
          @log.error( "ssl socket exception #{$!}")
        end
      }
    end

    def start(  listeningPort, &code)
      @threads << Thread.new {
        begin
          server = TCPServer.new('127.0.0.1', listeningPort)
          @log.info( "https listening on port #{listeningPort}")
          process_accept( server, &code)
        rescue
          @log.error( "ssl socket exception #{$!}")
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

