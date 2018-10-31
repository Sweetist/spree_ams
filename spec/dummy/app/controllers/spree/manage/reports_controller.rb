module Spree
  module Manage
	   class ReportsController < Spree::Manage::BaseController

      before_action :ensure_view_permissions, only: [:edit, :show, :new, :index]

       def products
         @products = current_vendor.products
         build_product_sales_chart
         render :products
       end

       def overview
         build_total_sales_chart
         render :overview
       end

       def customers
         build_customer_sales_area_chart
         build_customer_bar_chart
         build_customer_pie_chart
         render :customers
       end

       def selected_customer_data
         start_date = Time.zone.local(Time.current.year, 1, 1)
         end_date = Time.current
         customers = Hash.new(0)
         current_vendor.sales_orders.where("delivery_date >= ? AND delivery_date < ?", start_date, end_date).each do |order|
           customers[order.customer.name] += order.total
         end
         data = []
         customers.sort_by {|name, total| total}.reverse!.each do |name, total|
           data << {name: name, y: total.to_i}
         end
         data
       end

       def build_total_sales_chart
         start_date = Time.zone.local(Time.current.year, 1, 1)
         end_date = Time.current
         totals = Hash.new(0)
         current_vendor.sales_orders.where('delivery_date >= ? AND delivery_date <= ?', start_date, end_date).order('delivery_date ASC').each do |order|
           totals[order.delivery_date] += order.total
         end
         data = []
         totals.sort_by {|date, total| date}.each do |date, total|
           data << [date.to_i*1000, total.to_i]
         end


          @sales_overtime_chart = LazyHighCharts::HighChart.new('graph') do |f|
            f.chart({:type=>"area", :zoomType=>'x'})
            f.title(:text => "Sales Over Time - Year to Date")
            f.subtitle(text: 'Click and Drag to Zoom')
            f.legend(enabled: false)
            f.yAxis(title:{text: 'Total Sales (USD)'})
            f.options[:xAxis] = { :type => 'datetime',
             #  :lineWidth => 1,
             title: {text: Time.current.year.to_s},
              :tickInterval => (1000 * 60 * 60 * 24 * 365 / 12),
             #  :tickmarkPlacement => 'on',
              :startOnTick => true,
              :dateTimeLabelFormats => { :month => '%b' }}
            f.series(
              name: "Total Sales ($)",
              data: data,
              pointStart: Time.zone.local(Time.current.year, 1, 1),
              pointInterval: (1000 * 60 * 60 * 24 * 365 / 12)
            )

          f.plotOptions(series: {
            color: 'orange',
            fillColor:
            	{
                linearGradient: [0, 0, 0, 300],
                stops: [
                  [0,'orange' ],
                  [1, 'white']
                ]
             }
           })
         end
       end

       def build_customer_bar_chart
         start_date = Time.zone.local(Time.current.year, 1, 1)
         end_date = Time.current
         @customer_sales_bar_chart = LazyHighCharts::HighChart.new('graph') do |f|
            f.chart({:type=>"column", :className=>"bar active"})
            f.title(:text => "Sales by Customer")
            f.subtitle(text: "Year to Date")
            f.yAxis(title:{:text => "Total Sales (USD)"})
            f.legend(enabled: false)
            f.xAxis(:categories => [])
            f.series(
              colorByPoint: true,
              name: "Sales ($)",
              data: selected_customer_data
            )
          end
       end

       def build_customer_pie_chart
         start_date = Time.zone.local(Time.current.year, 1, 1)
         end_date = Time.current
 				@customer_sales_pie_chart = LazyHighCharts::HighChart.new('graph') do |f|
   				f.chart({:type=>"pie", :className=>"pie", margin: [30,30,70,30]})
 				  f.title(:text => "Sales by Customer")
          f.subtitle(text: "Year to Date")
 				  f.tooltip(pointFormat: '{series.name}: <b>{point.percentage:.1f}%</b>')
 					f.plotOptions(
 						pie: {
                 allowPointSelect: true,
                 cursor: 'pointer',
                 dataLabels: {
                     enabled: true,
                     format: '<b>{point.name}</b>: {point.percentage:.1f} %',
                     style: {
                         #color: (Highcharts.theme && Highcharts.theme.contrastTextColor) || 'black'
                         color: 'orange'
                     }
                 }
             }
 					)

           f.series(
 						name: "Percent of Total Sales",
             colorByPoint: true,
             data: selected_customer_data
         	)
 				end
 			end

       def build_customer_sales_area_chart
         start_date = Time.zone.local(Time.current.year, 1, 1)
         end_date = Time.current
          customers = []
          customers_totals = []
          current_vendor.customers.order('name ASC').each do |customer|
            customer_totals = []
            customer_totals = customer.purchase_orders.select(:total, :delivery_date).where("delivery_date >= ? AND delivery_date < ? AND vendor_id = ?", start_date, end_date, current_vendor.id).order('delivery_date ASC')
            customer_data = customer_totals.map{|c| [c.delivery_date.utc.to_i*1000 , c.total.to_i]}
            customers << [customer.name, customer_data]
          end

         @customer_sales_overtime_chart = LazyHighCharts::HighChart.new('graph') do |f|
           f.chart({:type => 'line', :zoomType=>'x'})
           f.title(:text => "Sales Over Time by Customer")
           f.subtitle(text: "Year to Date")
           f.yAxis(title:{:text => "Total Sales (USD)"})
             f.options[:xAxis] = { :type => 'datetime',
              #  :lineWidth => 1,
              #  :tickInterval => (1000 * 60 * 60 * 24 * 60),
              #  :tickmarkPlacement => 'on',
               :startOnTick => true,
               :dateTimeLabelFormats => { :month => '%b \'%y' }}

           customers.each do |customer|
             f.series(
                name: customer[0],
                data: customer[1],
                pointStart: Time.zone.local(Time.current.year, 1, 1),
                # pointInterval:
                # pointStart: Time.at(Time.zone.local(2015, 1, 1).to_i),
                pointInterval: (1000 * 60 * 60 * 24 * 30)
             )

           end

           f.plotOptions(series: {
                marker: {enabled: false}
                #  stacking: 'normal'
              }
           )

           f.legend(:align => 'right', :verticalAlign => 'top', :y => 75, :x => -50, :layout => 'vertical',)
         end
       end

       def build_product_sales_chart
         start_date = Time.zone.local(Time.current.year, 1, 1)
         end_date = Time.current
          customers = Hash.new {|hash, key| hash[key] = Hash.new(0)}
          # product_qtys = Hash.new([])
          product_qtys = Hash.new(0)
          product_totals = Hash.new(0)
          current_vendor.sales_orders.where("delivery_date >= ? AND delivery_date < ?", start_date, end_date).order('delivery_date ASC').each do |order|
            order.line_items.each do |line_item|
              prod_name = line_item.product.name
                product_qtys[prod_name] += line_item.quantity
                product_totals[prod_name] += line_item.total.to_i
                # product_qtys[name] << [line_item.quantity, order.delivery_date]
                # product_totals[prod_name] << [order.delivery_date.utc.to_i*1000, line_item.total.to_i]
                customers[order.customer.name][prod_name] += line_item.quantity
            end
          end

          @product_sales_overtime_chart = LazyHighCharts::HighChart.new('graph') do |f|
            f.chart({:type => 'area', :zoomType=>'x'})
            f.title(:text => "Sales Over Time by Product")
            f.subtitle(text: "Year to Date")
            f.yAxis(title:{:text => "Total Sales (USD)"})
              f.options[:xAxis] = { :type => 'datetime',
                :startOnTick => true,
                :dateTimeLabelFormats => { :month => '%b \'%y' }
              }

            product_totals.each do |name, data|
              f.series(
                 name: name,
                 data: data,
                 pointStart: Time.zone.local(Time.current.year, 1, 1),
                 # pointInterval:
                 # pointStart: Time.at(Time.zone.local(2015, 1, 1).to_i),
                 pointInterval: (1000 * 60 * 60 * 24 * 30)
              )
            end

            f.plotOptions(series: {
                 marker: {enabled: false},
                  stacking: 'normal'
               }
            )

            f.legend(:align => 'right', :verticalAlign => 'top', :y => 75, :x => -50, :layout => 'vertical',)
          end

          @product_sales_bar_chart = LazyHighCharts::HighChart.new('graph') do |f|
            data = []
            drill_series = []

            product_totals.sort_by {|name, total| total}.reverse!.each do |name, total|
              drill_data = []
              data << {name: name, y: total, drilldown: name}

              current_vendor.customers.each do |customer|
                 drill_data << [customer.name, customers[customer.name][name]]
              end

              drill_series << {name: name, id: name, data: drill_data}
            end

            f.plotOptions(
                series: {
                    borderWidth: 0,
                    dataLabels: {
                      format: '${y}',
                        enabled: true,
                    }
                }
            )

    				f.chart({:type=>"column", :className=>"bar active"})
  				  f.title(:text => "Sales by Product")
            f.subtitle(text: "Year to Date")
            f.yAxis(title:{:text => "Total Sales (USD)"})
            f.legend(enabled: false)
            f.xAxis(:categories => [])
               f.series(
                  colorByPoint: true,
                  name: "Sales ($)",
                  data: data
               )
               f.drilldown(series: drill_series)

  				end

          @product_qtys_bar_chart = LazyHighCharts::HighChart.new('graph') do |f|
            data = []
            drill_series = []

            product_qtys.sort_by {|name, qty| qty}.reverse!.each do |name, qty|
              drill_data = []
              data << {name: name, y: qty, drilldown: name}

              current_vendor.customers.each do |customer|
                 drill_data << [customer.name, customers[customer.name][name]]
              end

              drill_series << {name: name, id: name, data: drill_data}
            end

            f.plotOptions(
                series: {
                    borderWidth: 0,
                    dataLabels: {
                        enabled: true,
                    }
                }
            )

    				f.chart({:type=>"column", :className=>"bar active"})
  				  f.title(:text => "Sales by Product Quantities")
            f.subtitle(text: "Year to Date")
            f.yAxis(title:{:text => "Quantity"})
            f.legend(enabled: false)
            f.xAxis(:categories => [])
               f.series(
                  colorByPoint: true,
                  name: "Qty Sold",
                  data: data
               )
               f.drilldown(series: drill_series)

  				end
      end

      protected
        def ensure_view_permissions
          if current_spree_user.permissions.fetch('reports').fetch('basic_options') == 0
            flash[:error] = 'You do not have permission to view reports'
            redirect_to manage_path
          end
        end
      end

   end
 end
