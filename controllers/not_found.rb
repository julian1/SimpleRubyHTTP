
class NotFoundController

  def action( x)

    # resource not found
    if x[:response].nil?

      if /^GET.*$/.match(x[:request])
        # GET request
        x[:response] = "HTTP/1.1 404 Not Found"
        x[:response_headers]['Content-Type'] = "text/plain"
        x[:body] = StringIO.new( <<-EOF
  File not found!
          EOF
          )
      else
        # catch all, for non-implemented or badly formed request
        x[:response] = "HTTP/1.1 400 Bad Request"
        x[:response_headers]['Content-Type'] = "text/plain"
        x[:body] = StringIO.new( <<-EOF
  Your browser sent a request that this server could not understand
          EOF
          )
      end
    end


  end
end

