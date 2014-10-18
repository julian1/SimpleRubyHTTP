

# IMPORTANT be careful here. because this is a general controller 
# any response before here, will mean this doesn't run 

# Note this writes the x[:session] which is not available
# before this. 


class SessionController

  def initialize()
    # in memory session state for now
    @sessions = { }
  end

  def action( x)
    # IMPORTANT there's a potential bug, whereby if we change the attribute set,
    #  the cookie header will gets overwritten
    # by the multiple returned cookies.
    # actually shouldn't the browser only send one? although server can send multiple? 
    # we need to store them in an an array at decode..

    # IMPORTANT - We need, to change this to use Secure flag, then only send it
    # and only send on secure https connections 

    # IMPORTANT - we need to not send the session cookie, unless
    # we're https, and send with attribute Secure


    session_id = -1

#    if x[:socket].is_a?( OpenSSL::SSL::SSLSocket)

        sent_cookie = x[:request_headers]['Cookie']
        begin
          id, session_id = sent_cookie.split('=')
        rescue
          session_id = SecureRandom.uuid
#          new_cookie = "id=#{ session_id }; path=/; Secure"
          new_cookie = "id=#{ session_id }; path=/"
          x[:response_headers]['Set-Cookie'] = new_cookie
        end
#    end
    #puts "session_id is #{session_id}"

    # create new session
    @sessions[session_id] = {} if @sessions[session_id].nil?

    # alias
    x[:session] = @sessions[session_id]

    #puts "session data is #{x[:session] }"
  end

end

