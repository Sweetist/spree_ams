# # PDF header for invoice and packaging slip
# # Includes
# # 1 - vendor logo + address information in top-left
# # 2 - Order number, PO number, and date in top-right
# # 3 - Billing and shipping address of customer below top-most header, full-width
vendor = @doc.printable.vendor
pathname = if Rails.env.development?
  vendor.logo.attachment.path(:xlarge)
else
  f = open(vendor.logo.attachment.url(:xlarge))
  Dir.mkdir(Rails.root.join('tmp')) rescue nil
  file_name = URI.unescape(f.base_uri.path.split("/").last.to_s)
  file_path = Rails.root.join('tmp', file_name)
  File.open(file_path, 'wb') do |file|
    file << f.read
  end.path
end rescue nil

pathname = "" if pathname.blank?
if File.exist?(pathname)
	pdf.image pathname, vposition: :top, height: 30, scale: vendor.logo_scale
end

vendor_bill_address = vendor.bill_address

name = "#{vendor.name}"
street_address = "#{vendor_bill_address.try(:address1)}"
street_address << ", #{vendor_bill_address.address2}" unless vendor_bill_address.try(:address2).blank?
city_state_zip = ""
city_state_zip << "#{vendor_bill_address.city}, " unless vendor_bill_address.try(:city).blank?
city_state_zip << "#{vendor_bill_address.state_text}" unless vendor_bill_address.try(:state_text).blank?
city_state_zip << " #{vendor_bill_address.zipcode}" unless vendor_bill_address.try(:zipcode).blank?
phone = "#{vendor_bill_address.phone}" unless vendor_bill_address.try(:phone).blank?

pdf.indent(0) do
  unless File.exist?(pathname)
    pdf.text "#{name}", alight: :left, style: :bold, size: 18
  else
    pdf.move_down 4
    pdf.text "#{name}", alight: :left, style: :bold, size: 8
  end
  pdf.text "#{street_address}", alight: :left, size: 8
  pdf.text "#{city_state_zip}", alight: :left, size: 8
  pdf.text "#{phone}", alight: :left, size: 8
end
#
pdf.grid([0,3], [1,4]).bounding_box do
  pdf.text Spree.t(printable.document_type, scope: :print_invoice), align: :right, style: :bold, size: 18
  pdf.move_down 5

  po_label = pdf.make_cell(content: Spree.t(:po_number, scope: :print_invoice, po_number: ''))
  po_value = pdf.make_cell(content: printable.printable.po_number.to_s)
  order_label = pdf.make_cell(content: Spree.t("shipper_order_number", scope: :print_invoice, number: ''))
  order_value = pdf.make_cell(content: printable.number)
  data = [[po_label, po_value], [order_label, order_value]]

  pdf.table(data, header: false, position: :center,
    column_widths: [pdf.bounds.width / 2, pdf.bounds.width / 2],
    cell_style: { border_width: 1, borders: [], padding: 2}) do
    column(0..1).style align: :right
    column(1).style font_style: :bold, borders: [:bottom]
  end

end
