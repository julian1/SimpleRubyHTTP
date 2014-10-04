#!/usr/bin/ruby

require 'digest/md5'

# change module name to Asset ?
# or Static FileAsset

# adapted from, https://practicingruby.com/articles/implementing-an-http-file-server

module Static


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


    # Don't think we have to handle 404 here.
    # instead just leave everything ....

    def digest_file( x)
      path = requested_file( x[:request] )
      if File.exist?(path) && !File.directory?(path)
        Digest::MD5.hexdigest(File.read(path))
      else
        nil
      end
    end


    def serve_file( x )

      # no because we're also doing why don't we just return a valid stream descriptor here?

      path = requested_file( x[:request] )

      # Make sure the file exists and is not a directory
      # before attempting to open it.
      if File.exist?(path) && !File.directory?(path)
          x[:response] = "HTTP/1.1 200 OK"
          x[:response_headers]['Content-Type'] = "#{content_type(path)}"#,
		      x[:body] = File.open(path, "rb")
      end
    end

  end

end
