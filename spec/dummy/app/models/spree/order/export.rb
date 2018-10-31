module Spree::Order::Export
  def to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << [
        "Invoice Date",
        "Ship/Delivery Date",
        "Order #",
        "Account",
        "Item",
        "SKU",
        "QTY",
        "Price (#{self.first.try(:vendor).try(:currency)})"
      ]
      all.each do |order|
        invoice_date = DateHelper.display_vendor_date_format(order.invoice_date, order.vendor.date_format)
        delivery_date = DateHelper.display_vendor_date_format(order.invoice_date, order.vendor.date_format)
        order_number = order.display_number
        account_name = order.account.try(:fully_qualified_name)
        line_base = [
          invoice_date,
          delivery_date,
          order_number,
          account_name
        ]
        order.line_items.each do |li|
          line = line_base + [li.item_name,
                              li.sku,
                              li.quantity,
                              li.discount_price]
          csv << line
        end
        order.line_item_adjustments.promotion.eligible.group_by(&:label).each do |label, adjustments|
          csv << line_base + [
            "#{adjustments.first.source.try(:promotion).try(:name) || label}",
            nil, nil,
            adjustments.sum(&:amount)
          ]
        end
        order.adjustments.where.not(source_type: 'Spree::TaxRate').eligible.each do |adjustment|
          csv << line_base + [
            "#{adjustment.source.try(:promotion).try(:name) || adjustment.label}",
            nil, nil,
            adjustment.amount
          ]
        end
        order.all_adjustments.eligible.tax.group_by(&:label).each do |label, adjustments|
          csv << line_base + [
            "#{Spree.t(:tax)} #{label}",
            nil, nil,
            adjustments.sum(&:amount)
          ]
        end
        order.shipment_adjustments.promotion.eligible.group_by(&:label).each do |label, adjustments|
          csv << line_base + [
            "#{adjustments.first.source.try(:promotion).try(:name) || label}",
            nil, nil,
            adjustments.sum(&:amount)
          ]
        end
        csv << line_base + ["Ship via: #{order.shipping_method.try(:name)}", nil, nil, "#{order.shipment_total}"]
        csv << []
      end
    end
  end

  def to_xlsx(options)
    p = Axlsx::Package.new
    p.workbook.add_worksheet(:name => "Orders") do |sheet|
      sheet.add_row([
        "Invoice Date",
        "Ship/Delivery Date",
        "Order #",
        "Account",
        "Item",
        "SKU",
        "QTY",
        "Price (#{self.first.try(:vendor).try(:currency)})"
      ])
      all.each do |order|
        invoice_date = DateHelper.display_vendor_date_format(order.invoice_date, order.vendor.date_format)
        delivery_date = DateHelper.display_vendor_date_format(order.invoice_date, order.vendor.date_format)
        order_number = order.display_number
        account_name = order.account.try(:fully_qualified_name)
        line_base = [
          invoice_date,
          delivery_date,
          order_number,
          account_name
        ]
        order.line_items.each_with_index do |li, idx|
          line = line_base + [li.item_name,
                              li.sku,
                              li.quantity,
                              li.discount_price]
          sheet.add_row line
        end

        order.line_item_adjustments.promotion.eligible.group_by(&:label).each do |label, adjustments|
          sheet.add_row (line_base + [
            "#{adjustments.first.source.try(:promotion).try(:name) || label}",
            nil, nil,
            adjustments.sum(&:amount)
          ])
        end
        order.adjustments.where.not(source_type: 'Spree::TaxRate').eligible.each do |adjustment|
          sheet.add_row (line_base + [
            "#{adjustment.source.try(:promotion).try(:name) || adjustment.label}",
            nil, nil,
            adjustment.amount
          ])
        end
        order.all_adjustments.eligible.tax.group_by(&:label).each do |label, adjustments|
          sheet.add_row (line_base + [
            "#{Spree.t(:tax)} #{label}",
            nil, nil,
            adjustments.sum(&:amount)
          ])
        end
        order.shipment_adjustments.promotion.eligible.group_by(&:label).each do |label, adjustments|
          sheet.add_row (line_base + [
            "#{adjustments.first.source.try(:promotion).try(:name) || label}",
            nil, nil,
            adjustments.sum(&:amount)
          ])
        end
        sheet.add_row (line_base + [
          "Ship via: #{order.shipping_method.try(:name)}", nil, nil, "#{order.shipment_total}"
        ])
        sheet.add_row []
      end
    end
    p.use_shared_strings = true
    # p.serialize("orders_#{Date.today.to_s.underscore}.xlsx")
    p
  end

  def to_packing_list_report_xlsx(packing_list)
    p = Axlsx::Package.new
    p.workbook.add_worksheet(:name => "packing_list") do |sheet|
      sheet.add_row([
        "Customer Details",
        "Product",
        "Sku",
        "Lot #",
        "Pack/Size",
        "Units Count",
        "Quantity",
        "Total Units"
      ])
      starting_line_num = 2
      all.each do |order|
        address = order.ship_address
        col_a = [
          "Order: #{order.display_number}",
          "Item Count: #{order.item_count}",
          "Ship From: #{order.shipments[0].try(:stock_location).try(:name)}",
          "Ship via: #{order.shipping_method.try(:name)}",
          "Ship to: #{Spree::Address.display_addr_text(address, order.account.default_display_name)}"
        ].join("\n")
        ending_line_num = starting_line_num
        order.line_items.each_with_index do |line_item, idx|
        ending_line_num = starting_line_num + idx
          sheet.add_row [
            idx.zero? ? col_a : nil,
            line_item.variant.try(:full_display_name),
            line_item.variant.try(:sku),
            line_item.line_item_lots_text(line_item.line_item_lots, {sparse: true}),
            line_item.variant.try(:pack_size),
            line_item.variant.try(:pack_size_qty),
            line_item.quantity,
            line_item.quantity * line_item.variant.try(:pack_size_qty).to_f
          ]
       end
       unless ending_line_num == starting_line_num
         sheet.merge_cells("A#{starting_line_num}:A#{ending_line_num}")
       end
       starting_line_num = ending_line_num + 1

      end
    end
    p.use_shared_strings = true
    # p.serialize("orders_#{Date.today.to_s.underscore}.xlsx")
    p
  end

end
