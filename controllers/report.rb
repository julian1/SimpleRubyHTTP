
require 'json'


def map_query( conn, query, args, &code )
  # map a proc/block over postgres query result
  xs = []
  conn.exec( query, args ).each do |row|
    xs << code.call( row )
  end
  xs
end


class ReportController

  # this is not thread safe on the conn!!!
  # should be using a conn pool ? 
  def initialize(log, conn)
    @log = log
    @conn = conn
  end

  def action( x) 
	return if x[:response]

    matches = /^GET \/report.json\?field1=(.*)$/.match( x[:request])
    if matches and matches.captures.length == 1

      if x[:session][:authenticated] \
        && x[:session][:authenticated] == true

        # so we replace the + with space and then decode
        query = URI.decode( matches.captures[0].gsub(/\+/,' ') )

        @log.info( "got report query '#{query}'")

        # we should return json, or decode the json
        res = @conn .exec_params( query )

      # we could change this to avoid encoding the content field
      # which is already json as json. which would be interesting
      # that would enable us to actually see the message as well
      # rather than truncating it.

      rows = res.map do |row|
        row.to_json
      end

      s = " [ #{rows.join(', ')} ]"

        #   @log.info( "result is #{ w.string } ")
        x[:response] = "HTTP/1.1 200 OK"
        x[:response_headers]['Content-Type'] = "text/plain"
        x[:body] = StringIO.new( s )  # we shouldn't need this double handling
      else
        x[:response] = "HTTP/1.1 200 OK"
        x[:response_headers]['Content-Type'] = "text/plain"
        x[:body] = StringIO.new( "Please login first!!" )
      end
    end
  end
end


