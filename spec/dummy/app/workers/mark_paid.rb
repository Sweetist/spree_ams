class MarkPaid
  include Sidekiq::Worker

  def perform(vendor_id, obj_class, obj_ids)

    if obj_ids.count == 1
      mark_paid(vendor_id, obj_class, obj_ids.first)
    else
      enqueue_individual_jobs(vendor_id, obj_class, obj_ids)
    end
  end

  def mark_paid(vendor_id, obj_class, obj_id)
    obj = obj_class.constantize.where(vendor_id: vendor_id, id: obj_id).first
    return unless obj
    case obj_class
    when 'Spree::Order'
      unless obj.mark_paid
        obj.update_columns(payment_state: obj.updater.update_payment_state)
        obj.reload
        obj.update_invoice if obj.invoice
      end
    when 'Spree::Invoice'
      obj.orders.where(payment_state: 'updating').each do |order|
        unless order.mark_paid
          order.update_columns(payment_state: order.updater.update_payment_state)
        end
      end
      obj.update_counts
    end
  end

  def enqueue_individual_jobs(vendor_id, obj_class, obj_ids)
    obj_ids.each do |obj_id|
      Sidekiq::Client.push(
        'class' => MarkPaid,
        'queue' => 'critical',
        'args' => [vendor_id, obj_class, [obj_id]]
      )
    end
  end
end
