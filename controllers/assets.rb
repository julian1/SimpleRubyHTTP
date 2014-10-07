

class AssetsController

  def initialize(content)
    @content = content
  end

  def action( x)
	return if x[:response]

    matches = /^GET (.*\.txt|.*\.html|.*\.css|.*\.js|.*\.jpeg|.*\.png|.*\.ico)$/.match(x[:request])
    if matches && matches.captures.length == 1

      digest = @content.digest_file( x )
      if_none_match = x[:request_headers]['If-None-Match']

      if digest && if_none_match && if_none_match == digest
        x[:response] = "HTTP/1.1 304 Not Modified"
      else
        # eg. serve normal 200 OK
        @content.serve_file( x )
        x[:response_headers]['ETag'] = digest
      end
    end
  end
end

