
require "uri"
require 'zlib'
require 'stringio'
require 'json'
require 'logger'


module Helper

  def Helper.encode_cookie( fields, attributes )
    fields = fields.keys.map do |key|
      "#{key}=#{fields[key]}" 
    end
    s = fields.join(":")
    s += "; "
    attributes = attributes.keys.map do |key|
      "#{key}=#{attributes[key]}" 
    end
    s += attributes.join("; ")
    s
  end

  def Helper.decode_cookie(raw_cookie)
    fields = {}
    attributes = {}
    raw_cookie.split(/[;]\s?/).each_with_index do |pairs, index|
      if index == 0
        fields = {} 
        pairs.split(/\:/).each do |pairs|
          key, val = pairs.split('=') 
          fields[key] = val
        end
      else
        key, val = pairs.split('=') 
        attributes[key] = val
      end
    end
    return fields,attributes
  end





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


#     # there's all these things that interact - cookies, compression, keep alives, cache-control, ssl
#
#     # actually we could construct a pipeline that has two calls.
#     # content and headers.
#
#     # that way we can abstract the filling in of the size. and compression.
#     # lower levels - handle db,file stream, set response 404, 200 etc, cache control
#     # other levels - cookies.
#     # top level compression, keep-alive etc.
#


    # this is failing on, with new line behavior
    #  echo -e 'GET / HTTP/1.1' | nc localhost 2345 | less

    #request = {}
    # probably should structure this differenly...
    # if it's a post, then we will want to slurp a lot more...

    # ok, we have to avoid calling it twice,

    # I don't think we can actually call gets, if we don't
    # know for certain ... whether more data should arrive...

    # I don't see how we can know that we're finshed - if it's HTTP/1.0
    # and there are no headers.

    # no it will be terminated by another \r\n

    # i think it's correct - we have to block twice to know when http finishes.

#   def Helper.decode_request( x )
#
#     socket = x[:socket]
#     x[:request] = socket.gets
#     while line = socket.gets("\r\n")  # this blocks, because there's nothing more to read after the first line.
#                                       # i think this is correct behavior
#       break if line == "\r\n"
#       s = line.split(':')
#       x[:request_headers][ s[0].strip] = s[1].strip
#     end
#   end

  def Helper.ignore_exception
     begin
     yield
     rescue Exception
    end
  end




end

