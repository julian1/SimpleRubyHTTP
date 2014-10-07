
Minimal HTTP server, supporting

    - SSL sockets/certs
    - keep-alive/persistent http
    - compression
    - cookies/session management
    - cache control - with etags /http if-none-found/ 304
    - url rewriting
    - streaming io (using file/stringio - still need chunked transfer) .
    - filter chains
    - static assets from file-system
    - 302 redirect to https
    - mime mappping
    - simple example of event sourcing model 

TODO

    - chunked transfer
    - websockets
    - cache cotnrol example using last-modified
    - public cache example would be interesting

	
		
    - also need a json configuration file, that we can feed to ingest webserver
      actually not sure - main already assembles main graph

    - work out how to start and drop down into lower privileged account
        
    - and stop exceptions from being silently trapped
      
    - combine the response and response_headers like webrick


    class Simple < WEBrick::HTTPServlet::AbstractServlet
      def do_GET request, response
        status, content_type, body = do_stuff_with request

        response.status = 200
        response['Content-Type'] = 'text/plain'
        response.body = 'Hello, World!'
      end
    end

    fix get_id update which isnt working

