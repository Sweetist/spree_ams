module ReportHelper
  def self.sorted_data(data_hash, show_count = 10)
    data = []
    remainder = Hash.new(0)
    idx = 0
    data_hash.sort_by {|name, total| total}.reverse!.each do |name, total|
      if idx < show_count
        data << {name: name, y: total.to_i}
      else
        remainder[:others] += total.to_i
      end
      idx += 1
    end

    if remainder[:others] > 0
      data << {name: "Others (Avg)", y: remainder[:others]/(data_hash.keys.count - show_count)}
    end
    data
  end

  # http://jsfiddle.net/gh/get/jquery/1.7.2/highslide-software/highcharts.com/tree/master/samples/highcharts/plotoptions/area-fillcolor-gradient/

  def self.build_areaspline_chart(data, title, y_title)
    {
      chart: {
        type: 'areaspline',
        zoomType: 'x'
      },
      colors: ['#346DA4'],
      title: {
        text: title
      },
      subtitle: {
        text: 'Click and Drag to Zoom'
      },
      legend: {
        enabled: false
      },
      yAxis: {
        title: {
          text: y_title
        }
      },
      xAxis: {
        type: 'datetime'
      },
      plotOptions: {
        series: {
          color: 'orange',
          marker: {
            enabled: false
          },
          fillColor: {
            linearGradient: [0, 0, 0, 300],
            stops: [
              [0,'orange' ],
              [1, 'white']
            ]
          }
        }
      },
      credits: { enabled: false },
      series: [
        {
          name: '',
          data: data
        }
      ]
    }
  end

  def self.build_bar_chart(data, series_name, title, y_title)
    {
      chart: {
        type: 'column',
        className: 'bar active',
      },
      colors: ['#346DA4'],
      title: {
        text: title
      },
      legend: {
        enabled: false
      },
      yAxis: {
        title: {
          text: y_title
        }
      },
      xAxis: {
        categories: []
      },
      credits: { enabled: false },
      series: [
        {
          name: series_name,
          colorByPoint: true,
          data: data
        }
      ]
    }
  end

  def self.build_pie_chart(data, series_name, title)
    {
      chart: {
        type: 'pie',
        className: 'pie',
        margin: [30, 30, 70, 30]
      },
      colors: ['#346DA4'],
      title: {
        text: title
      },
      tooltip: {
        pointFormat: '{series.name}: <b>{point.percentage:.1f}%</b>'
      },
      plotOptions: {
        pie: {
          allowPointSelect: true,
          cursor: 'pointer',
          dataLabels: {
            enabled: true,
            format: '<b>{point.name}</b>: {point.percentage:.1f} %',
            style: {
              color: 'orange'
            }
          }
        }
      },
      credits: { enabled: false },
      series: [
        {
          name: series_name,
          colorByPoint: true,
          data: data
        }
      ]
    }
  end

end
