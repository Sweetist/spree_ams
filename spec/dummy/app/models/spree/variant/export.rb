module Spree::Variant::Export
  def to_production_report_xlsx(options = {})
    p = Axlsx::Package.new
    p.workbook.add_worksheet(:name => "Production") do |sheet|
      sheet.add_row([
        "Name",
        "Sku",
        "Pack/Size",
        "Unit Count",
        "Quantity",
        "Total Unit Qty",
        "Total Weight"
      ])
      Spree::Variant.full_production_list(options[:vendor], options[:start_date], options[:end_date], options[:order_states], options[:account_ids]).each do |v|
        sheet.add_row [
          v.full_display_name,
          v.sku,
          v.pack_size,
          v.pack_size_qty,
          v.quantity,
          v.quantity.to_f * v.pack_size_qty.to_f,
          "#{v.quantity.to_f * v.weight.to_f} #{v.weight_units}"
        ]
      end
    end
    p.use_shared_strings = true
    # p.serialize("orders_#{Date.today.to_s.underscore}.xlsx")
    p
  end
end
