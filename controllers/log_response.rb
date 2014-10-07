
class LogResponseController

  def initialize(log)
    @log = log
  end

  def action( x)
    # ip = x[:socket].peeraddr[3]
    # @log.info( "response from #{ip} '#{ x[:response] ? x[:response].strip : "nil"  }'" )
  end
end


