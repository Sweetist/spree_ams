order = printable.printable
# ship_address = printable.ship_address
billing = ''
shipping = ''

pdf.move_down 2
address_cell_billing  = pdf.make_cell(content: Spree.t(:purchase_from), font_style: :bold)
address_cell_shipping = pdf.make_cell(content: Spree.t(:ship_to), font_style: :bold)

billing = Spree::Address.display_addr_text(
  (order.try(:account).try(:bill_address) || order.try(:account).try(:billing_addresses).last),
  order.try(:vendor).try(:name))
shipping = Spree::Address.display_addr_text(order.try(:po_stock_location), order.try(:customer).try(:name))

data = [[address_cell_billing, address_cell_shipping], [billing, shipping]]

pdf.table(data, position: :center, column_widths: [pdf.bounds.width / 2, pdf.bounds.width / 2])
