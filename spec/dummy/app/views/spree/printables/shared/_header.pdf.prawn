# PDF header for invoice and packaging slip
# Includes
# 1 - vendor logo + address information in top-left
# 2 - Order number, PO number, and date in top-right
# 3 - Billing and shipping address of customer below top-most header, full-width
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

pdf.grid([0,3], [1,4]).bounding_box do
  pdf.text Spree.t(printable.document_type, scope: :print_invoice), align: :right, style: :bold, size: 18
  pdf.move_down 4

  if @doc.printable.is_a?(Spree::Invoice)
    pdf.text Spree.t("#{vendor.order_or_invoice_text.to_s.downcase}_number", scope: :print_invoice, number: printable.number), align: :right
  else
    pdf.text Spree.t("#{printable.document_type}_number", scope: :print_invoice, number: printable.number), align: :right
  end

  unless printable.printable.try(:po_number).blank?
    pdf.move_down 2
    pdf.text Spree.t(:po_number, scope: :print_invoice, po_number: printable.printable.po_number), align: :right
  end

  if @doc.printable.is_a?(Spree::Order)
    pdf.move_down 2
    pdf.text Spree.t("#{printable.document_type}_date", scope: :print_invoice, date_type: vendor.order_date_text.to_s.capitalize, date: printable.printable.display_date), align: :right
  end

  if printable.printable.is_a?(Spree::Invoice)
    pdf.move_down 2
    pdf.text Spree.t("#{printable.document_type}_invoicedate", scope: :print_invoice, date: printable.printable.display_date), align: :right
    pdf.move_down 2
    pdf.text Spree.t("#{printable.document_type}_duedate", scope: :print_invoice, date: printable.printable.display_due_date), align: :right

    terms = @doc.printable.try(:account).try(:payment_terms).try(:name)
    if terms.present?
      pdf.move_down 2
      pdf.text "#{Spree.t(:terms)}: #{terms}", align: :right
    end

    if vendor.cust_can_view?('order', 'payment_state')
      pdf.move_down 2
      status = printable.printable.payment_status
      pdf.text "Payment Status: #{Spree.t(status, scope: :payment_statuses, default: [:missing, '']).to_s.titleize}", align: :right
    end
  end
end
