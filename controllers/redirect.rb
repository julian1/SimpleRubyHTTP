
# should change name to ssl redirect

class RedirectController

  # need to pass in arguments as to ports, hostname etc 

  def initialize( log, hostname, port)
    @log = log
    @hostname = hostname
    @port = port
  end

  def action( x)
    unless x[:socket].is_a?( OpenSSL::SSL::SSLSocket)
      @log.info( "redirect to https" )
      x[:response] = "HTTP/1.1 302 Found"
      x[:response_headers]['Location'] = "https://#{@hostname}:#{@port}"
    end
  end	 
end

