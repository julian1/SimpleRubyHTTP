#!/usr/bin/ruby

# adapted from, https://practicingruby.com/articles/implementing-an-http-file-server


module Static

# we want to separate out the networking, from message routing/redirect, from file stuff. 

def Static.requested_file(request_line)

	puts "-----------------"
	puts "request_line -> #{request_line}"
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
  File.join(Dir.pwd , *clean)
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

# This helper function parses the extension of the
# requested file and then looks up its content type.

def Static.content_type(path)
  ext = File.extname(path).split(".").last
  CONTENT_TYPE_MAPPING.fetch(ext, DEFAULT_CONTENT_TYPE)
end

def Static.serve_file( keys, socket )

  path = Static.requested_file( keys['request'])

  # Make sure the file exists and is not a directory
  # before attempting to open it.
  if File.exist?(path) && !File.directory?(path)
    File.open(path, "rb") do |file|
      socket.print "HTTP/1.1 200 OK\r\n" +
                   "Content-Type: #{content_type(file)}\r\n" +
                   "Content-Length: #{file.size}\r\n" #+
#                   "Connection: close\r\n"

      socket.print "\r\n"

      # write the contents of the file to the socket
      IO.copy_stream(file, socket)
    end
  else
    message = "File not found\n"

    # respond with a 404 error code to indicate the file does not exist
    socket.print "HTTP/1.1 404 Not Found\r\n" +
                 "Content-Type: text/plain\r\n" +
                 "Content-Length: #{message.size}\r\n" #+
#                 "Connection: close\r\n"

    socket.print "\r\n"

    socket.print message
  end
end


end
