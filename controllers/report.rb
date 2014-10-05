


class ReportController

  # this is not thread safe on the conn!!!
  # should be using a conn pool ? 
  def initialize(log, conn)
    @log = log
    @conn = conn
  end

  def action( x) 

    puts "*** WHOOT report controller action " 

    matches = /^GET \/report.json\?field1=(.*)$/.match( x[:request])
    if matches and matches.captures.length == 1

      if x[:session][:authenticated] \
        && x[:session][:authenticated] == true

        # so we replace the + with space and then decode
        query = URI.decode( matches.captures[0].gsub(/\+/,' ') )

        @log.info( "got report query '#{query}'")

        # we should return json, or decode the json
        res = @conn .exec_params( query )
        w = StringIO.new()
        res.each do |row|
            w.puts row
        end
        #   @log.info( "result is #{ w.string } ")
        x[:response] = "HTTP/1.1 200 OK"
        x[:response_headers]['Content-Type'] = "text/plain"
        x[:body] = StringIO.new( w.string )  # we shouldn't need this double handling
      else
        x[:response] = "HTTP/1.1 200 OK"
        x[:response_headers]['Content-Type'] = "text/plain"
        x[:body] = StringIO.new( "Please login first!!" )
      end
    end
  end
end


