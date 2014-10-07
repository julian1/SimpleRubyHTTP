
# stuff that's currently in helper should move into here,

class SendResponseController

  def action( x)

    Helper.write_response( x )

	# write some stats
    x[:session][:last_access] = Time.now
    begin
      x[:session][:page_count] += 1
    rescue
      x[:session][:page_count] = 0
    end

  end
end

