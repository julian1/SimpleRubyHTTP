
class LogResponseController

  def initialize(log)
    @log = log
  end

  def action( x)
    # ip = x[:socket].peeraddr[3]
    # @log.info( "response from #{ip} '#{ x[:request] ? x[:request].strip : "nil"  }'" )
  end
end


