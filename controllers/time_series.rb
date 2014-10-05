


class TimeSeriesController
  # I think that the model reader can actually be turned into this.

  def initialize(model)
    @model = model
  end

  def action(x )
    if /^GET \/get_series.json$/.match(x[:request])
      @model.get_series( x)
    end

    # this whole id thing, where client submits id to check for state change, is
    # almost equivalent to etag approach
    if /^GET \/get_id.json$/.match(x[:request])
      @model.get_id( x )
    end
  end
end


