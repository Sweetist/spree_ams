module Integrations
  module Payment
    attr_reader :order

    def process_for(order)
      return unless payments_data
      @order = order
      handle_payments_data
    end

    def handle_payments_data
      payments_data.each do |payment_data|
        if payment_data['kind'] == 'refund'
          create_refund(payment_data) unless update_by(payment_data, 'Spree::Refund')
        else
          create_payment(payment_data) unless update_by(payment_data, 'Spree::Payment')
        end
      end
    end

    def update_by(payment_data, klass)
      transaction_object = find_object_by(sync_id: payment_data['id'],
                                          sync_type: sync_type,
                                          klass: klass)
      transaction_object ||= payment_by_type if klass == 'Spree::Payment'
      transaction_object ||= refund_by_type(payment_data) if klass == 'Spree::Refund'
      return unless transaction_object
      transaction_object.update_columns(amount: payment_data['amount'])
    end

    def payment_by_type
      order.payments.find_by(payment_method: payment_method)
    end

    def refund_by_type(payment_data)
      payment_by_type.refunds
                     .find_by(refund_reason_id: refund_reason.id,
                              amount: payment_data['amount'])
    end

    def payment_state(payment_data)
      return 'checkout' if payment_data['status'] == 'success'
      nil
    end

    def create_payment(payment_data)
      return unless payment_state(payment_data)

      payment = order.payments.build order: order
      payment.amount = payment_data['amount'].to_f
      payment.state = payment_state(payment_data) if payment_state(payment_data)
      payment.created_at = payment_data['created_at'] if payment_data['created_at']
      payment.payment_method = payment_method
      payment.save!
      payment.process! if payment.state == 'checkout'
      create_assign_sync_id(payment, payment_data['id'])
    end

    def create_refund(payment_data)
      return unless payment_state(payment_data)
      return unless payment_by_type

      refund = payment_by_type.refunds.create!(reason: refund_reason,
                                               amount: payment_data['amount'])
      create_assign_sync_id(refund, payment_data['id'])
    end

    def refund_reason
      Spree::RefundReason
        .find_or_create_by(name: "#{sync_type.camelize} refund")
    end

    def payment_method
      Spree::PaymentMethod
        .find_or_create_by(type: 'Spree::PaymentMethod::Other',
                           auto_capture: true,
                           name: 'other')
    end

    def payments_data
      raise Error, I18n.t('integrations.please_implement_in_integration')
    end
  end
end
