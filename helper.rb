
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


  def Helper.write_json( content_io, socket )
      headers = { 
          'response' => "HTTP/1.1 200 OK\r\n", 
          'Content-Type:' => "application/json\r\n"
      }
      Helper.write_response( headers, content_io, socket )
  end



  def Helper.write_response( headers, content_io, socket )

      # this stuff needs to be added to the pipeline

      # it would be really nice to support chunked streaming

      if false 
        # don't compress
        content = content_io.read
        headers['Content-Length:'] =  "#{content.bytesize}\r\n" 
      end

      # we could actually read the header field to decide whether to compress or not
      # or the request object
      if true
        # compress
        wio = StringIO.new("w")
        w_gz = Zlib::GzipWriter.new(wio)
        IO.copy_stream(content_io, w_gz )
        w_gz.close
        content = wio.string
      
        puts "*** content after compressing #{content.bytesize}" 

        headers['Content-Encoding:'] = "gzip\r\n"
        headers['Content-Length:'] =  "#{content.bytesize}\r\n" 
      end 

      # write response...
      socket.print headers['response']

      # write other header fields
      headers.keys.each do |key|
        next if key == 'response'
        socket.print "#{key} #{headers[key]}"
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
 

  def Helper.decode_request( socket )
    request = {}
    # probably should structure this differenly...
    # if it's a post, then we will want to slurp a lot more...
    request['request'] = socket.gets
    while line = socket.gets
      break if line == "\r\n"
      s = line.split(':')
      request[ s[0].strip] = s[1].strip 
    end
    #puts request
    request
  end

  def Helper.ignore_exception
     begin
     yield  
     rescue Exception
    end
  end


  def Helper.write_hello_message( request, socket )

    cookie = 0
    cookie = ignore_exception {  request[ 'Cookie'].to_i + 1 }
    puts "setting cookie to #{cookie}"

    response = "Hello World!\n"

    # We need to include the Content-Type and Content-Length headers
    # to let the client know the size and type of data
    # contained in the response. Note that HTTP is whitespace
    # sensitive, and expects each header line to end with CRLF (i.e. "\r\n")

    # In HTTP 1.1, all connections are considered persistent unless declared otherwise.
    socket.print "HTTP/1.1 200 OK\r\n" +
    "Content-Type: text/plain\r\n" +
    "Content-Length: #{response.bytesize}\r\n" +
    "Set-Cookie: #{cookie}\r\n" +
    "Connection: Keep-Alive\r\n" +
    "\r\n"

    # Print the actual response body, which is just "Hello World!\n"
    socket.print response
  end


  def Helper.write_redirect_message( request, socket )

    response = <<-EOS  
      <!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
      <html><head>
      <title>302 Found</title>
      </head><body>redirect
      <h1>Found</h1>
      <p>The document has moved</a>.</p>
      <hr>
      <address>Apache Server at imos.aodn.org.au Port 80</address>
      </body></html>
    EOS
   
    socket.print "HTTP/1.1 302 Found\r\n" + 
      "Date: Sun, 21 Sep 2014 09:02:16 GMT\r\n" + 
      "Server: Apache\r\n" +
      "Location: https://localhost:1443\r\n" + 
      "Vary: Accept-Encoding\r\n" + 
      "Content-Length: 282\r\n" +
      "Content-Type: text/html; charset=iso-8859-1\r\n" +
      "\r\n"

    # Print the actual response body, which is just "Hello World!\n"
    socket.print response
  end

end

