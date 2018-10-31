order = printable.printable
# ship_address = printable.ship_address
billing = ''
shipping = ''

from_address = order.shipments.first.try(:stock_location)
ship_address = printable.ship_address

pdf.move_down 2
address_cell_billing  = pdf.make_cell(content: Spree.t(:from).upcase, font_style: :bold)
address_cell_shipping = pdf.make_cell(content: Spree.t(:to).upcase, font_style: :bold)

billing = Spree::Address.display_addr_text(from_address, order.try(:vendor).try(:name))
shipping = Spree::Address.display_addr_text(ship_address, order.try(:customer).try(:name))

data = [[address_cell_billing, address_cell_shipping], [billing, shipping]]

pdf.table(data, position: :center, column_widths: [pdf.bounds.width / 2, pdf.bounds.width / 2], cell_style: { border_width: 0.1})
