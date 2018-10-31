account = @doc.printable.account
customer = account.customer
pathname = if Rails.env.development?
  customer.logo.attachment.path(:xlarge)
else
  f = open(customer.logo.attachment.url(:xlarge))
  Dir.mkdir(Rails.root.join('tmp')) rescue nil
  file_name = URI.unescape(f.base_uri.path.split("/").last.to_s)
  file_path = Rails.root.join('tmp', file_name)
  File.open(file_path, 'wb') do |file|
    file << f.read
  end.path
end rescue nil

pathname = "" if pathname.blank?
if File.exist?(pathname)
  pdf.image pathname, vposition: :top, height: 30, scale: customer.logo_scale
end

customer_bill_address = customer.try(:bill_address)

if customer_bill_address
  name = "#{customer_bill_address.try(:company)}"
  street_address = "#{customer_bill_address.try(:address1)}"
  street_address << ", #{customer_bill_address.address2}" unless customer_bill_address.try(:address2).blank?
  city_state_zip = ""
  city_state_zip << "#{customer_bill_address.city}, " unless customer_bill_address.try(:city).blank?
  city_state_zip << "#{customer_bill_address.state_text}" unless customer_bill_address.try(:state_text).blank?
  city_state_zip << " #{customer_bill_address.zipcode}" unless customer_bill_address.try(:zipcode).blank?
  phone = "#{customer_bill_address.phone}" unless customer_bill_address.try(:phone).blank?

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
end


pdf.grid([0,3], [1,4]).bounding_box do
  pdf.text "Purchase Order", align: :right, style: :bold, size: 18
  pdf.move_down 4

  if @doc.printable.is_a?(Spree::Invoice)
    pdf.text Spree.t("#{customer.order_or_invoice_text.to_s.downcase}_number", scope: :print_invoice, number: printable.number), align: :right
  else
    pdf.text "#{printable.number}", align: :right
  end

  pdf.move_down 2
  pdf.move_down 2
  pdf.text printable.printable.display_date, align: :right

end
