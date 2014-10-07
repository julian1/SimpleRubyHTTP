


class AuthController

  def initialize()
    @secret = 'pineapple123'
  end

  def serve_response( x)
    x[:body] = StringIO.new( <<-EOF
        { "authenticated": #{ 
          x[:session][:authenticated] \
          && x[:session][:authenticated] == true \
          ? "true" : "false" 
        } }
      EOF
      )
      x[:response] = "HTTP/1.1 200 OK"
      #x[:response_headers]['Content-Type'] = "text/plain"
      x[:response_headers]['Content-Type'] = "application/json" 
  end

  def action( x)
	return if x[:response]
    # two methods test whether authenticated and login
    # these things are controllers - they ought to be classes

    # should explicitly test for port 1443 again

    matches = /^GET \/authenticated.json$/.match( x[:request])
    if matches
      serve_response( x)
    end

    matches = /^GET \/login.json\?field1=(.*)$/.match( x[:request])
    if matches and matches.captures.length == 1

      query = URI.decode( matches.captures[0].gsub(/\+/,' ') )
      if( query == @secret)
        x[:session][:authenticated] = true
      end
      serve_response( x)
    end
  end
end


