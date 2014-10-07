
# cannot be a general controller, because it
# wants to apply to everything after this point

class CachePolicyController

  def action( x)
    unless x[:response_headers]['Cache-Control']
        #x[:response_headers]['Cache-Control']= "private"
        x[:response_headers]['Cache-Control']= "private, max-age=0"
    end
  end
end

