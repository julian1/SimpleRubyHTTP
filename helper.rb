
require "uri"

require 'zlib'
require 'stringio'
require 'json'


module Helper


  def Helper.gzip(string)
    wio = StringIO.new("w")
    w_gz = Zlib::GzipWriter.new(wio)
    w_gz.write(string)
    w_gz.close
    compressed = wio.string
    compressed
  end


#   def Helper.write_json( content_io, socket )
#       headers = { 
#           'response' => "HTTP/1.1 200 OK", 
#           'Content-Type:' => "application/json"
#       }
#       Helper.write_response( headers, content_io, socket )
#   end
# 


  #def Helper.write_response( headers, content_io, socket )
  def Helper.write_response( x )

      # this stuff needs to be added to the pipeline

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


      # max-age=0
      headers['Cache-Control']= "private"

 #     headers['Cache-Control:']= "private,max-age=100000"

  # firefox will send 'If-None-Match' nicely. dont have to set cache-control flags 



      if false 
        # don't compress
        content = x[:body].read
        headers['Content-Length'] =  "#{content.bytesize}" 
      end

      # we could actually read the header field to decide whether to compress or not
      # or the request object
      if true 
        # compress
        wio = StringIO.new("w")
        w_gz = Zlib::GzipWriter.new(wio)
        IO.copy_stream( x[:body], w_gz )
        w_gz.close
        content = wio.string
      
        puts "*** content after compressing #{content.bytesize}" 

        headers['Content-Encoding'] = "gzip"
        headers['Content-Length'] =  "#{content.bytesize}" 
      end 

      # Ok, we don't really have to wrap the stream to do chuncked encoding etc.
      # instead we can localise the behavior here. 

      socket = x[:socket]

      ### socket operations, could have exception if client disconnected
      ### without following http protocol

      # write response...
      socket.print x[:response]


      socket.print "\r\n"

      # write other header fields
      headers.keys.each do |key|
        #next if key == 'response'
        socket.print "#{key}:#{headers[key]}\r\n"
      end

      socket.print "\r\n"

      # write content
      socket.print content 

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


# 
#   def Helper.write_redirect_message( request, socket )
# 
#     response = <<-EOS  
#       <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
#       <html><head>
#       <title>302 Found</title>
#       </head><body>redirect
#       <h1>Found</h1>
#       <p>The document has moved</a>.</p>
#       <hr>
#       <address>Apache Server at imos.aodn.org.au Port 80</address>
#       </body></html>
#     EOS
#    
#     socket.print "HTTP/1.1 302 Found" + 
#       "Date: Sun, 21 Sep 2014 09:02:16 GMT\r\n" + 
#       "Server: Apache\r\n" +
#       "Location: https://localhost:1443\r\n" + 
#       "Vary: Accept-Encoding\r\n" + 
#       "Content-Length: 282\r\n" +
#       "Content-Type: text/html; charset=iso-8859-1\r\n" +
#       "\r\n"
# 
#     # Print the actual response body, which is just "Hello World!\n"
#     socket.print response
#   end
# 
end

