
class RedirectController

  # need to pass in arguments as to ports, hostname etc 

  def initialize( log)
    @log = log

  end

  def action( x)
    port = x[:socket].addr[1]
    if port == 8000
      @log.info( "redirect to https" )
      x[:response] = "HTTP/1.1 302 Found"
      x[:response_headers]['Location'] = "https://localhost:1443"
    end

  end	 

end

