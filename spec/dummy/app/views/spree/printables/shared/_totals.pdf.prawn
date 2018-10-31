# TOTALS
totals = []
orders = invoice.printable.orders
# Subtotal
unless invoice.item_total == invoice.total
  totals << [pdf.make_cell(content: Spree.t(:subtotal)), invoice.display_item_total.to_s]
end
# Adjustments
invoice.line_item_adjustments.promotion.eligible.group_by(&:label).each do |label, adjustments|
  if invoice.multi_order
    totals << [pdf.make_cell(content: "#{adjustments.first.source.try(:promotion).try(:name)} (Order ##{adjustments.first.order.display_number})"), Spree::Money.new(adjustments.sum(&:amount), currency: invoice.currency).to_s]
  else
    totals << [pdf.make_cell(content: "#{adjustments.first.source.try(:promotion).try(:name)}"), Spree::Money.new(adjustments.sum(&:amount), currency: invoice.currency).to_s]
  end
end
invoice.adjustments.eligible.each do |adjustment|
  if invoice.multi_order
    totals << [pdf.make_cell(content: "#{adjustment.source.try(:promotion).try(:name) || adjustment.label} (Order ##{adjustment.order.display_number})"), Spree::Money.new(adjustment.amount, currency: invoice.currency).to_s]
  else
    totals << [pdf.make_cell(content: "#{adjustment.source.try(:promotion).try(:name) || adjustment.label}"), Spree::Money.new(adjustment.amount, currency: invoice.currency).to_s]
  end
end
invoice.shipment_adjustments.promotion.eligible.each do |adjustment|
  if invoice.multi_order
    totals << [pdf.make_cell(content: "#{adjustment.source.try(:promotion).try(:name)} (Order ##{adjustment.order.display_number})"), Spree::Money.new(adjustment.amount, currency: invoice.currency).to_s]
  else
    totals << [pdf.make_cell(content: "#{adjustment.source.try(:promotion).try(:name)}"), Spree::Money.new(adjustment.amount, currency: invoice.currency).to_s]
  end
end

# Tax
unless invoice.additional_tax_total == 0
  totals << [pdf.make_cell(content: Spree.t(:tax)), Spree::Money.new(invoice.additional_tax_total, currency: invoice.currency).to_s]
end
unless invoice.included_tax_total == 0
  totals << [pdf.make_cell(content: Spree.t(:included_tax)), Spree::Money.new(invoice.included_tax_total, currency: invoice.currency).to_s]
end
# Shipments
# unless invoice.shipment_total == 0
  if orders.any?{|order| order.shipping_method.try(:rate_tbd) && !order.override_shipment_cost}
    totals << [pdf.make_cell(content: Spree.t(:shipping)), 'TBD']
  else
    totals << [pdf.make_cell(content: Spree.t(:shipping)), Spree::Money.new(invoice.shipment_total, currency: invoice.currency).to_s]
  end
# end

# Totals
totals << [pdf.make_cell(content: Spree.t(:total)), invoice.display_total.to_s]
vendor = @doc.printable.vendor

rows_from_bottom = 1
if vendor.invoice_pdf_include_balance
  rows_from_bottom += 2
  totals << ['Paid', Spree::Money.new(orders.sum(:payment_total), currency: invoice.currency).to_s]
  pending_balance = orders.map(&:pending_balance).sum
  if pending_balance > 0
    rows_from_bottom += 1
    totals << ['Pending', Spree::Money.new(pending_balance, currency: invoice.currency).to_s]
  end
  balance = orders.map(&:remaining_balance).sum
  totals << ['Balance', Spree::Money.new(balance, currency: invoice.currency).to_s]
end

totals_table_width = [0.875, 0.125].map { |w| w * pdf.bounds.width }
pdf.table(totals, column_widths: totals_table_width) do
  row(0..-1).style align: :right
  row(0..-1).style borders: [], font_style: :bold
  row(-rows_from_bottom).style borders: [:top], border_width: 0.1
end
