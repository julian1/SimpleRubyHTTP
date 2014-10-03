#!/usr/bin/ruby

# adapted from, https://practicingruby.com/articles/implementing-an-http-file-server

module Static

  # do we really need this. or can we return
  # just a tuple { headers, } ???
  # a tuple is not as capable as this class if we
  # really want to pipeline

  # we can just use a tuple if that's sufficient. 
  # also full iostream implementation might be too much, because 
  # we cannot copy it.

  # what if we want xml, rather than json?
  class Result
    def initialize( headers, io_content )
      @headers = headers
      @io_content = io_content
    end
    def headers
      @headers
    end
    def io_content
      @io_content
    end
  end


  # we should be initalizing this with the web root in the constructor.
  # we can then serve different roots with different cache control etc.
  # we want to  separate out the networking, from message routing/redirect, from file stuff.


  class FileContent

    def initialize( dir)
      @dir = dir
    end

    def requested_file(request_line)

      #puts "request_line -> #{request_line}"
      request_uri  = request_line.split(" ")[1]

      path         = URI.unescape(URI(request_uri).path)
      clean = []
      # Split the path into components

      parts = path.split("/")
      parts.each do |part|
        # skip any empty or current directory (".") path components
        next if part.empty? || part == '.'
        # If the path component goes up one directory level (".."),
        # remove the last clean component.
        # Otherwise, add the component to the Array of clean components
        part == '..' ? clean.pop : clean << part
      end
      # return the web root joined to the clean path
      #WEB_ROOT='/home/meteo'
      #_WEB_ROOT=Dir.pwd
      #File.join(WEB_ROOT, *clean)
      #File.join(Dir.pwd , *clean)
      File.join( @dir , *clean)
    end


      # Map extensions to their content type
      CONTENT_TYPE_MAPPING = {
        'html' => 'text/html',
        'txt' => 'text/plain',
        'png' => 'image/png',
        'jpg' => 'image/jpeg'
      }

      # Treat as binary data if content type cannot be found
      DEFAULT_CONTENT_TYPE = 'application/octet-stream'



    def content_type(path)
      # This helper function parses the extension of the
      # requested file and then looks up its content type.

      ext = File.extname(path).split(".").last
      CONTENT_TYPE_MAPPING.fetch(ext, DEFAULT_CONTENT_TYPE)
    end

 
    # sending the Etag gives us
    # we definitely need to construct a pipeline. 
    # if-none-match

    # Hmmm we can just append the file timestamp to the etag  ...
	# and if it matches return 304
	# or md5 ing the file

    def serve_file( x )

      path = requested_file( x[:request] )

      # Make sure the file exists and is not a directory
      # before attempting to open it.
      if File.exist?(path) && !File.directory?(path)
        if true
          x[:response] = "HTTP/1.1 200 OK\r\n"
          x[:response_headers]['Content-Type:'] = "#{content_type(path)}\r\n"#,
		      x[:body] = File.open(path, "rb")

#           Result.new(
#             {
#               x[:response] => "HTTP/1.1 200 OK\r\n",
#               x{:response_headers]['Content-Type:'] => "#{content_type(path)}\r\n"#,
# #              'ETag:' => "\"#{path}\"\r\n"
#             },
#             File.open(path, "rb")
#          )
        else

          abort( 'file not found 1 ' )

          Result.new(
            {
              'response' => "HTTP/1.1 304 Not Modified\r\n"
            },
            StringIO.new("") 
          )
        end
      else


          abort( 'file not found 2 ' )

        Result.new(
          {
            'response' => "HTTP/1.1 404 Not Found\r\n",
            'Content-Type:' => "text/plain\r\n"
          },
          StringIO.new( <<-EOF
            file not found
          EOF
          )
        )
      end
    end

  end

end
