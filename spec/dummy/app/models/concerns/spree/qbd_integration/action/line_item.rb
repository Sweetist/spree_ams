module Spree::QbdIntegration::Action::LineItem

  def qbd_txn_line_to_line_item(txn_line, txn_object)
    variant = qbd_find_variant_by_id_or_name(txn_line, 'ItemRef')
    if variant.nil?
      raise "Must create or pull item '#{txn_line.fetch('ItemRef', {}).fetch('FullName', nil)}' before syncing invoice."
    end
    txn_class = nil
    if txn_line.fetch('ClassRef', nil)
      txn_class = qbd_find_transaction_class_by_id_or_name(txn_line, 'ClassRef')
    end
    qty = txn_line.fetch('Quantity', 1).to_d
    if txn_line.fetch('RatePercent', nil)
      if qty.zero?
        rate = txn_line('Amount', 0).to_d
      else
        rate = txn_line('Amount', 0).to_d / qty
      end
    else
      rate = txn_line.fetch('Rate', 0).to_d
    end
    line_item = nil

    if txn_object.present?
      line_item = txn_object.line_items.new(
        variant_id: variant.id,
        item_name: variant.fully_qualified_name,
        txn_class_id: txn_class.try(:id),
        quantity: qty,
        price: rate,
        lot_number: txn_line.fetch('LotNumber', ''),
        tax_category_id: variant.tax_category_id,
        currency: self.company.currency
      )
    end

    line_item
  end
end
