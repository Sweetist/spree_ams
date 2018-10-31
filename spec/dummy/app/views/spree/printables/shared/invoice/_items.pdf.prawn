vendor = @doc.printable.vendor
view_settings = vendor.customer_viewable_attribute
headers_left = []
headers_right = []
headers_left << :sku if view_settings.variant_sku
headers_left << :lot_number if view_settings.line_item_lot_number && !invoice.multi_order
headers_left << :item_description
headers_left << :pack_size if view_settings.variant_pack_size
headers_right << :unit_weight if vendor.try(:invoice_pdf_include_unit_weight)
headers_right << :price
headers_right << :qty
headers_right << :total_weight if vendor.try(:invoice_pdf_include_total_weight)
headers_right << :total
header_attrs = headers_left + headers_right

header = header_attrs.map{|attribute| pdf.make_cell(content: Spree.t(attribute))}

data = [header]

invoice.items.each do |item|
  row = []
  row << item.sku if view_settings.variant_sku
  row << item.lot_number if view_settings.line_item_lot_number && !invoice.multi_order
  row << item.name
  row << item.try(:pack_size) if view_settings.variant_pack_size
  row << item.try(:unit_weight) if vendor.try(:invoice_pdf_include_unit_weight)
  row << Spree::Money.new(item.price, currency: item.currency).to_s
  row << item.quantity
  row << item.total_weight if vendor.try(:invoice_pdf_include_total_weight) && !vendor.try(:multi_order)
  row << Spree::Money.new(item.total, currency: item.currency).to_s
  data += [row]

  if item.parts.present? && item.show_parts
    item.parts.each do |part|
      part_data = []
      part_data << nil
      part_data << part.lot_number if view_settings.line_item_lot_number && !invoice.multi_order
      part_data << { content: part.flat_or_nested_name, colspan: 3, padding: [5, 5, 5, 5] }
      part_data << part.total
      part_data << nil
      data += [part_data]
    end
  end

end

column_widths = []
extra = 0
if view_settings.variant_sku
  column_widths << 0.10
else
  extra += 0.10
end
if view_settings.line_item_lot_number && !invoice.multi_order
  column_widths << 0.10
else
  extra += 0.10
end

column_widths << 0.28
if view_settings.variant_pack_size
  column_widths << 0.105
else
  extra += 0.105
end
if vendor.try(:invoice_pdf_include_unit_weight)
  column_widths << 0.08
else
  extra += 0.08
end
column_widths << 0.075
column_widths << 0.08
if vendor.try(:invoice_pdf_include_total_weight)
  column_widths << 0.09
else
  extra += 0.08
end
column_widths << 0.09

if extra > 0 && column_widths.length > 0
  extra = (extra / column_widths.length).round(3)
  column_widths[0..-2] = column_widths[0..-2].map { |w| w += extra }
  column_widths[-1] = 1 - (column_widths[0..-2].inject(:+)).round(3)
end

column_widths.map! { |w| w * pdf.bounds.width }

pdf.table(data, header: true, position: :center, column_widths: column_widths, cell_style: { border_width: 0.1, borders: [:bottom]}) do
  row(0).style align: :center, font_style: :bold
  column(0...headers_left.length).style align: :left
  column((headers_left.length)..-1).style align: :right
end
