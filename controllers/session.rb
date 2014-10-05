

# be careful here. because this is a general controller 
# any response before here, will mean this doesn't run 

class SessionController

	# Note this writes the x[:session] which is not available
  # before this. 

  def initialize()

    #
    @sessions = { }

  end

  def action( x)
    # there's a bit of a bug, in which if we change the attributes,
    # and get multiple sessions, the cookie header gets overwritten
    # by the multiple returned cookies.

    # IMPORTANT - We need, to change this to use Secure flag, then only send it
    # when the connection is https

    sent_cookie = x[:request_headers]['Cookie']
    session_id = -1
    begin
      id, session_id = sent_cookie.split('=')
    rescue
      session_id = SecureRandom.uuid
      new_cookie = "id=#{ session_id }; path=/"
      x[:response_headers]['Set-Cookie'] = new_cookie
    end

    puts "session_id is #{session_id}"

    # create new session
    @sessions[session_id] = {} if @sessions[session_id].nil?
    x[:session] = @sessions[session_id]

    puts "session data is #{x[:session] }"
  end



end

