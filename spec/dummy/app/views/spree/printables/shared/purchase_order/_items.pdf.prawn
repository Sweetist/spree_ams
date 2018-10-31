vendor = @doc.printable.vendor
customer = @doc.printable.customer
headers_left = []
headers_right = []
headers_left << :sku
headers_left << :item_description
headers_left << :pack_size
headers_right << :unit_weight if customer.try(:po_pdf_include_unit_weight)
headers_right << :price if customer.try(:po_pdf_price)
headers_right << :qty
headers_right << :total_weight if customer.try(:po_pdf_include_total_weight)
headers_right << :total if customer.try(:po_pdf_price)
header_attrs = headers_left + headers_right

header = header_attrs.map{|attribute| pdf.make_cell(content: Spree.t(attribute))}

data = [header]

printable.items.each do |item|
  row = []
  row << item.sku
  row << item.name
  row << item.try(:pack_size)
  row << item.try(:unit_weight) if customer.try(:po_pdf_include_unit_weight)
  row << Spree::Money.new(item.price, currency: item.currency).to_s if customer.try(:po_pdf_price)
  row << item.quantity
  row << item.total_weight if customer.try(:po_pdf_include_total_weight)
  row << Spree::Money.new(item.total, currency: item.currency).to_s if customer.try(:po_pdf_price)
  data += [row]


  if item.parts.present? && item.show_parts
    item.parts.each do |part|
      part_data = []
      part_data << nil
      part_data << { content: part.flat_or_nested_name, padding: [5, 5, 5, 30] }
      part_data << part.total
      data += [part_data]
    end
  end
end

column_widths = []
extra = 0.0
column_widths << 0.125
column_widths << 0.320
column_widths << 0.100
if customer.try(:po_pdf_include_unit_weight)
  column_widths << 0.10
else
  extra += 0.10
end
if customer.try(:po_pdf_price)
  column_widths << 0.08
else
  extra += 0.08
end
column_widths << 0.075
if customer.try(:po_pdf_include_total_weight) && !vendor.try(:multi_order)
  column_widths << 0.10
else
  extra += 0.10
end
if customer.try(:po_pdf_price)
  column_widths << 0.10
else
  extra += 0.10
end

if extra > 0 && column_widths.length > 0
  extra = (extra / column_widths.length).round(3)
  column_widths[0..-2] = column_widths[0..-2].map { |w| w += extra }
  column_widths[-1] = 1 - (column_widths[0..-2].inject(:+)).round(3)
end

column_widths.map! { |w| w * pdf.bounds.width }

pdf.table(data, header: true, position: :left, column_widths: column_widths, cell_style: { border_width: 0.1, borders: [:bottom]}) do
  row(0).style align: :center, font_style: :bold
  column(0...headers_left.length).style align: :center
  column(headers_left.length..-1).style align: :center
end

pdf.move_down 10

subtotal = []
subtotal << 'Subtotal' #name
subtotal << @doc.item_count
subtotal << @doc.printable.display_total_weight_in(customer.try(:weight_units)) if customer.try(:po_pdf_include_total_weight)
subtotal << Spree::Money.new(@doc.item_total, currency: @doc.currency).to_s if customer.try(:po_pdf_price)

right_cols = 1
right_cols += 1 if customer.try(:po_pdf_price)
right_cols += 1 if customer.try(:po_pdf_include_total_weight)

subtotal_col_widths = [column_widths[0...-right_cols].inject(:+), column_widths[(column_widths.count - right_cols)..-1]].flatten
pdf.table([subtotal], header: false, position: :left, column_widths: subtotal_col_widths, cell_style: { border_width: 0, borders: [:bottom]}) do
  row(0).style align: :center, font_style: :bold
  column(0).style align: :right
end
