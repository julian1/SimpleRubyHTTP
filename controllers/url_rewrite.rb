
class URLRewriteController

  def action( x)
    return if x[:response]


    # eases subsequent matching
    # - think we should do this before the post, and not care
    # irrespective of the actual http verb
    matches = /^(GET .*)\s(HTTP.*)/.match(x[:request])
    if matches and matches.captures.length == 2
      x[:request] = matches.captures[0]
    end


    # rewrite top level / to index.html
    if matches = /^GET \/$/.match(x[:request])
      x[:request] = "GET /index.html"
    end
  end

end
