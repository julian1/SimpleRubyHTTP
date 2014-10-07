
# stuff that's currently in helper should move into here,


require "uri"
require 'zlib'
require 'stringio'
require 'json'
require 'logger'


module Helper

  def Helper.gzip(string)
    wio = StringIO.new("w")
    w_gz = Zlib::GzipWriter.new(wio)
    w_gz.write(string)
    w_gz.close
    compressed = wio.string
    compressed
  end


  def Helper.write_response( x )

    # it would be really nice to support chunked streaming

    if x[:response].nil? || x[:response] == ""
      # should just raise an exception...
      abort( "*** missing response!!!" )
    end

    headers = x[:response_headers]
    if headers.nil? || headers.length == 0

      # should just raise an exception...
      abort( "*** missing response headers !!!"  )
    end


    if false
      # don't compress
      content = x[:body].read
      headers['Content-Length'] =  "#{content.bytesize}"
    end

    ## We shouldnt be compressing already compressed assets like images.

    # we could actually read the header field to decide whether to compress or not
    # or the request object
    if x[:body]
      # compress
      wio = StringIO.new("w")
      w_gz = Zlib::GzipWriter.new(wio)
      IO.copy_stream( x[:body], w_gz )
      w_gz.close

      content = wio.string
      headers['Content-Encoding'] = "gzip"
      headers['Content-Length'] =  "#{content.bytesize}"

    else

      headers['Content-Length'] =  "0"
    end

    # Ok, we don't really have to wrap the stream to do chuncked encoding etc.
    # instead we can localise the behavior here.

    socket = x[:socket]

    ### socket operations, could have exception if client disconnected
    ### without following http protocol

    # write http response
    socket.print x[:response]

    socket.print "\r\n"

    # write other header fields
    headers.keys.each do |key|
      socket.print "#{key}: #{headers[key]}\r\n"
    end

    socket.print "\r\n"

    if x[:body]

      # write content
      socket.print content
    end

  end


end


class SendResponseController

  def action( x)

    Helper.write_response( x )

	# write some stats
    x[:session][:last_access] = Time.now
    begin
      x[:session][:page_count] += 1
    rescue
      x[:session][:page_count] = 0
    end

  end
end


