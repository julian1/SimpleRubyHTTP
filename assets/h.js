
  var options = {
    series: {
      lines: {
        show: true
      }
//,
//        points: {
//          radius: 5,
//          fill: true,
//          show: true
//        }
    },
    yaxes: [
      {
//		show: true,
		label: "usd",
        position: "right"
      },
      {
//		show: true,
		label: "aud",
        position: "left"
      },
     {
		label: "percent",
        position: "left"
      }

    
    ],
    xaxis: {
      mode: "time",
      // tickSize: [3, "minute"],
      tickLength: 0,
      axisLabel: "time",
      label: "time",
		  // these don't look correctly named
      axisLabelUseCanvas: true,
      axisLabelFontSizePixels: 12,
      axisLabelFontFamily: 'Verdana, Arial',
      axisLabelPadding: 10,
      tickFormatter: function (val, axis) {
        //return dayOfWeek[new Date(val).getDay()];
        //return val.toLocaleTimeString()
        return new Date( val).toLocaleTimeString();
      }
    }
  };


  // we could actually keep this entire model on the server side if we wanted. 
  // but wouldn't it be better to be able to get individual series ...
  // yes. 
  // we could specify defaults - like {color, axis } 
  // so would it be better to update asynchronously.

  // eg. we have a bunch of series - when one of them are returned 
  // we redraw the model
  // we should know the name. 

  // i think we need to fire of an ajax request for every series 
  
  // ok, all_series should be kept about so that we can edit it.
  // it's actually a model.
  
  // IMPORTANT - we should be using backbone or something
  // if we request a series - we can get back the fully structured

 
  function find_index(a, predicate) {
    // must be a jquery equivalent
    for (var i = 0; i < a.length; i++) {
      if(predicate(a[i])) 
        return i;
    }
    return -1;
  }


  function merge_series( new_series ) {
    i = find_index( all_series, function( elt) { 
      return elt.name === new_series.name; 
    }); 
    //console.log( 'index is ' + i ); 
    if(i === -1) { 
      all_series.push( new_series );
    } else {
      all_series[i] = new_series;
    }
    //console.log( 'all_series.length after merge ' + all_series.length ); 
  }

 
  function add_series( series_name_ ) {
    $.ajax({
      dataType: "json",
      url: "get_series.json",
      data: { 
        ticks: $( "#myticks" )[0].value, 
        name: series_name_
      },

		// change series_name to just name
      success: function ( result, textStatus, jqXHR ) {
        // ok, 
        //console.log( 'whoot got series!!! ' + series_name_ );
		var axis_to_use = find_index( options.yaxes, function( axis ) { 
			return axis.label === result.unit 
		}); 
		// why not call it name not series_name ??
        new_series = {
            name:	result.name, 
			last_id: result.last_id,
            color:	result.color, 
            label:	result.name + '\(' + result.unit + '\)',
            unit:	result.unit,
            yaxis:	axis_to_use + 1,
            data:	result.data.map( function(x) {
              return [ new Date( x.time), x.value ]
            })
        };

		last_timestamp1 = $( new_series.data).last()[0][0] 
		// multiple series - means there's no definitive
		if( !last_timestamp || last_timestamp1 > last_timestamp) { 
			last_timestamp = last_timestamp1;
		}

		$( "#starttime" ).html( '<p>Valid: ' 
			+ 	$.format.date(last_timestamp, "dd-MM-yyyy HH:mm")
			+ "</p>" );

        merge_series( new_series ); 
        refresh_chart_data();
      },
      error: function (jqXHR, textStatus, errorThrown ) {
        console.log( textStatus  + errorThrown );
      }
    });
  }


  function refresh_chart_data() { 
    // rather than lexically bind everything - should use param
    // factor this into a function ...
    // actually we should even pass the all_series as an argument
    if( graph == null) {
      graph = $.plot($("#placeholder"), all_series, options );
      //console.log( 'plotting graph')
    }
    else {
      //console.log( 'already have graph')
      graph.setData( all_series );  // Replace oldData with newData
      graph.setupGrid();       // Adjust axes to match new values
      graph.draw();            // Update actual plot
    }
  }


	var pending = 0;

  function continuous_update() {
	// change name to heartbeat or something?
	//console.log('*** continuous_update ' + all_series.length );
	if( pending != 0) {
		return;	
	}	
	// store it on the series - layer. 	
	$.each( all_series, function( i, series) {
		// console.log('*** calling update for ' + series['name'] );
		pending++;
		$.ajax({
		  dataType: "json",
		  data: { name: series['name'] },
		  url: "get_series_id.json",
		  success: function ( id, textStatus, jqXHR ) {
			//console.log( "id is " + id  );
			//console.log( 'last_id is ' + series['last_id'] );
			if( id != series['last_id'] ) {
				//console.log( "updating!!" );
				add_series( series['name']); 
			}
		  },
		  complete: function ( id, textStatus, jqXHR ) {
			pending--;
			//console.log( 'pending is ' + pending );
		  }
		});
	});
	setTimeout(continuous_update, 10 * 1000 );
  }

