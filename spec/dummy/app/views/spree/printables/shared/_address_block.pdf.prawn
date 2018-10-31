bill_address = printable.bill_address
ship_address = printable.ship_address
billing = ''
shipping = ''

pdf.move_down 2
address_cell_billing  = pdf.make_cell(content: Spree.t(:billing_address), font_style: :bold)
address_cell_shipping = pdf.make_cell(content: Spree.t(:shipping_address), font_style: :bold)

if bill_address
  billing << "#{printable.printable.try(:account).try(:fully_qualified_name)}"
  billing << "\n#{bill_address.firstname} #{bill_address.lastname}" unless bill_address.firstname.blank?
  billing << "\n#{bill_address.address1}"
  billing << "\n#{bill_address.address2}" unless bill_address.address2.blank?
  billing << "\n#{bill_address.city}, #{bill_address.state_text} #{bill_address.zipcode}" unless bill_address.city.blank?
  billing << "\n#{bill_address.country.name}" unless bill_address.country.blank?
  billing << "\n#{bill_address.phone}"
end

if ship_address
  shipping << "#{printable.printable.try(:account).try(:fully_qualified_name)}"
  shipping << "\n#{ship_address.firstname} #{ship_address.lastname}" unless ship_address.firstname.blank?
  shipping << "\n#{ship_address.address1}"
  shipping << "\n#{ship_address.address2}" unless ship_address.address2.blank?
  shipping << "\n#{ship_address.city}, #{ship_address.state_text} #{ship_address.zipcode}" unless ship_address.city.blank?
  shipping << "\n#{ship_address.country.name}" unless ship_address.country.blank?
  shipping << "\n#{ship_address.phone}"
end

data = [[address_cell_billing, address_cell_shipping], [billing, shipping]]

pdf.table(data, position: :center, column_widths: [pdf.bounds.width / 2, pdf.bounds.width / 2])
