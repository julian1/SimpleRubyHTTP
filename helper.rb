
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
  
  def Helper.write_json( content, socket )

# seems to be an issue when returning gzipped content for chromium and wget
# but not firefox. we really need to see the headers...
   
    # how about chunked encoding and streaming? 
    # should we be writing here, or should we be returning an object,  

    # there's all these things that interact - cookies, compression, keep alives, cache-control, ssl 

    # actually we could construct a pipeline that has two calls.
    # content and headers. 

    # that way we can abstract the filling in of the size. and compression. 
    # lower levels - set response, 
    # other levels - cookies. 
    # top level compression, keep-alive etc.
     
    puts "size before compress #{content.bytesize}"
    content = gzip( content )

    puts "size after #{content.bytesize}"

    socket.print "HTTP/1.1 200 OK\r\n" +
          "Content-Type: application/json\r\n" +
          "Content-Length: #{content.bytesize}\r\n" + 
          "Content-Encoding: gzip\r\n"

    socket.print "\r\n"
    socket.print content
  end


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
    puts "here0"
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
