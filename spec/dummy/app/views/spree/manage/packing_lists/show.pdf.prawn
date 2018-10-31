font_style = {
  # face: @doc.printable.vendor.font_face,
  size: 12
}
prawn_document do |pdf|
  # pdf.define_grid(columns: 5, rows: 8, gutter: 10)
  pdf.font font_style[:face], size: font_style[:size]

  start_date = "#{display_vendor_date_format(@dates[:start], @vendor.date_format)}"
  end_date = "#{display_vendor_date_format(@dates[:end], @vendor.date_format)}"
  if start_date == end_date
    pdf.text "Packing List #{start_date}"
  else
    pdf.text "Packing List #{start_date} to #{end_date}"
  end
  pdf.move_down 10
  # CONTENT

  view_settings = @vendor.customer_viewable_attribute
  headers_left = []
  headers_right = []
  headers_left << :customer_details
  headers_left << :product
  headers_left << :sku  if view_settings.variant_sku
  headers_left << :lot_number if view_settings.line_item_lot_number
  headers_left << :pack_size if view_settings.variant_pack_size
  headers_right << :pack_size_qty
  headers_right << :qty
  headers_right << :total_units
  header_attrs = headers_left + headers_right

  header = header_attrs.map{|attribute| {content: Spree.t(attribute)}}

  column_widths = []
  extra = 0
  column_widths << 0.22
  column_widths << 0.17

  if view_settings.line_item_lot_number
    column_widths << 0.15
  else
    extra += 0.15
  end
  if view_settings.variant_pack_size
    column_widths << 0.14
  else
    extra += 0.14
  end
  if view_settings.variant_sku
    column_widths << 0.11
  else
    extra += 0.11
  end
  column_widths << 0.07
  column_widths << 0.07
  column_widths << 0.07

  if extra > 0 && column_widths.length > 1
    extra = (extra / (column_widths.length - 1)).round(3)
    column_widths[1..-2] = column_widths[1..-2].map{ |w| w += extra }
    column_widths[-1] = 1 - (column_widths[0..-2].inject(:+)).round(3)
  end

  column_widths.map! { |w| w * pdf.bounds.width }
  # pdf.repeat(:all) do
    pdf.table([header], column_widths: column_widths) do
      row(0).style font_style: :bold, size: 8
    end
  # end



  data = @all_orders.map do |order|
    ["#{order.pack_list_customer_details}",
      if order.line_items.any?
        pdf.make_table(order.line_items.map do |item|
          row = []
          row << item.item_name
          row << item.variant.try(:sku) if view_settings.variant_sku
          row << item.line_item_lots_text(item.line_item_lots, {sparse: true}) if view_settings.line_item_lot_number
          row << item.variant.try(:pack_size) if view_settings.variant_pack_size
          row << item.variant.try(:pack_size_qty)
          row << item.quantity
          row << (item.variant.try(:pack_size_qty).present? ? "#{item.quantity * item.variant.try(:pack_size_qty).to_f}" : nil)
          row
        end, column_widths: column_widths[1..-1]) do
          column(0..10).style size: 8
        end
      end
    ]
  end

  column_widths = [0.22,0.78].map { |w| w * pdf.bounds.width }
  unless data.empty?
    pdf.table(data, header: false, column_widths: [column_widths[0], column_widths[1..-1].inject(:+)] ) do
      column(0).style align: :left, font_style: :bold
      column(0...headers_left.length).style align: :left, size: 8
      column(headers_left.length..-1).style align: :center, size: 8
    end
  end


end
