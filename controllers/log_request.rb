
class LogRequestController

  def initialize(log)
    @log = log
  end

  def action( x)
    # getpeername, and getsockname are better, but unsupported for sslsocket
    # see -> http://stackoverflow.com/questions/19315361/obtaining-client-address-with-ruby-sslsockets
    # port, ip = Socket.unpack_sockaddr_in(x[:socket].getpeername)

    ip = x[:socket].peeraddr[3]
    @log.info( "request from #{ip} '#{ x[:request] ? x[:request].strip : "nil"  }'" )
  end
end


