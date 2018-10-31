module Spree::QbdIntegration::Action::PaymentMethod
  #
  # Payment Methods
  # NOTE This is a work in progress and does not work in it's current state
  # There are issues trying to use the payment_id, rather than the payment_method_id.
  # We are doing this because there is not sufficient information on our payment
  # methods to map directly to PaymentMethod in QBD.  In Sweet, PaymentMethod basically
  # defines a Gateway, while in QBD it is more generic, such as CreditCard, but also requires a
  # Type field that is more specific such as Visa, MasterCard, etc.
  #
  def qbd_payment_method_step(payment_id, parent_step_id = nil)
    payment = Spree::Payment.find(payment_id)
    payment_hash = payment.to_integration(
        self.integration_item.integrationable_options_for(payment)
      )
    payment_method_id = payment_hash.fetch(:payment_method_id)
    payment_method_hash = payment_hash.fetch(:payment_method)
    payment_match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: payment_id,
      integration_syncable_type: 'Spree::Payment',
      sync_type: 'ReceivePayment'
    )

    method_match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: payment_method_id,
      integration_syncable_type: 'Spree::PaymentMethod',
      sync_type: 'PaymentMethod'
    )
    if method_match.sync_id.nil?
      { step_type: :query, next_step: :skip, object_id: payment_method_id, object_class: 'Spree::PaymentMethod', sync_type: 'PaymentMethod', qbxml_class: 'PaymentMethod', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    elsif method_match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      { step_type: :create, object_id: payment_id, object_class: 'Spree::PaymentMethod', sync_type: 'PaymentMethod', qbxml_class: 'PaymentMethod', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    else
      { step_type: :query, next_step: :skip, object_id: payment_method_id, object_class: 'Spree::PaymentMethod', sync_type: 'PaymentMethod', qbxml_class: 'PaymentMethod', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    end
  end

  def qbd_payment_method_to_payment_method_xml(xml, payment_hash, match = nil)
    payment_method_hash = payment_hash.fetch(:payment_method)
    xml.Name                payment_method_hash.fetch(:name)
    xml.IsActive            payment_method_hash.fetch(:active)
    xml.PaymentMethodType   qbd_payment_method_type(payment_hash.fetch(:source_type), payment_hash.fetch(:source))
  end

  def qbd_payment_method_type(type, source)
    # Must be one of the following
    # AmericanExpress, Cash, Check, DebitCard, Discover, ECheck, GiftCard, MasterCard, Other, OtherCreditCard, Visa
    case type
    when 'Spree::CreditCard'
      case source.cc_type.to_s.downcase
      when 'master'
        'MasterCard'
      when 'visa'
        'Visa'
      when 'discover'
        'Discover'
      when 'american_express'
        'AmericanExpress'
      else
        'OtherCreditCard'
      end
    else
      'Other'
    end
  end

  def qbd_payment_method_xml_to_payment_method(response, payment_method_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/PaymentMethodRs/PaymentMethodRet'
    {
      name: response.xpath("#{xpath_base}/Name").try(:children).try(:text)
    }.delete_if { |k, v| v.blank? }
  end

  def qbd_all_associated_matched_payment_method?(response, object_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/PaymentMethodRs/PaymentMethodRet'
    qbd_hash = Hash.from_xml(response.xpath(xpath_base).to_xml).fetch("PaymentMethodRet", {})

    qbd_payment_method_find_or_assign_associated_opts(qbd_hash)

    self.reload.current_step.try(:sub_steps).try(:incomplete).blank?
  end

  def qbd_payment_method_find_or_assign_associated_opts(qbd_hash, payment_method = nil)

  end

end
