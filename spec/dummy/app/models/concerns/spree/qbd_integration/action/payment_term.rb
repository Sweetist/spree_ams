module Spree::QbdIntegration::Action::PaymentTerm
  #
  # Payment Terms
  #
  def qbd_payment_term_step(payment_term_id, parent_step_id = nil)
    match = self.integration_item.integration_sync_matches.find_or_create_by(integration_syncable_id: payment_term_id, integration_syncable_type: 'Spree::PaymentTerm')
    if match.sync_id.nil?
      { step_type: :query, next_step: :skip, object_id: payment_term_id, object_class: 'Spree::PaymentTerm', qbxml_class: 'StandardTerms', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    elsif match.sync_id.empty? && self.integration_item.qbd_create_related_objects
      { step_type: :create, object_id: payment_term_id, object_class: 'Spree::PaymentTerm', qbxml_class: 'StandardTerms', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    else
      { step_type: :query, next_step: :skip, object_id: payment_term_id, object_class: 'Spree::PaymentTerm', qbxml_class: 'StandardTerms', qbxml_query_by: 'FullName', qbxml_match_by: 'ListID'}
    end
  end

  def qbd_payment_term_to_standard_terms_xml(xml, payment_term_hash, match = nil)
    if match.try(:sync_id)
      xml.ListID       match.try(:sync_id)
      # xml.EditSequence match.try(:sync_alt_id)
    end
    xml.Name           payment_term_hash.fetch(:name)
    xml.StdDueDays     payment_term_hash.fetch(:due_in_days)
  end

  def qbd_standard_terms_xml_to_payment_term(response, payment_term_hash)
    xpath_base = '//QBXML/QBXMLMsgsRs/StandardTermsRs/StandardTermsRet'
    {
      # Payment Terms are shared, so we do not want to update anything here
      # name: response.xpath("#{xpath_base}/Name").try(:children).try(:text)
    }.delete_if { |k, v| v.blank? }
  end

  def qbd_find_payment_term_by_id_or_name(hash, base_key)
    qbd_payment_term_id = hash.fetch(base_key, {}).fetch('ListID', nil)
    qbd_payment_term_full_name = hash.fetch(base_key, {}).fetch('FullName', nil)
    return nil unless qbd_payment_term_id.present? || qbd_payment_term_full_name.present?

    match = self.integration_item.integration_sync_matches.where(
      integration_syncable_type: 'Spree::PaymentTerm',
      sync_id: qbd_payment_term_id
    ).first

    payment_term = Spree::PaymentTerm.where(id: match.try(:integration_syncable_id)).first
    payment_term ||= Spree::PaymentTerm.where(name: qbd_payment_term_full_name).first

    if payment_term.nil?
      raise "Unable to find PaymentTerm '#{qbd_payment_term_full_name}'. Please contact Sweet."
      # sync_step = self.integration_steps.find_or_initialize_by(
      #   integrationable_type: 'Spree::PaymentTerm',
      #   sync_type: 'Terms',
      #   sync_id: qbd_payment_term_id
      # )
      # sync_step.parent_id ||= self.current_step.try(:id)
      # sync_step.details = qbd_payment_term_pull_step_hash.merge(
      #   {'qbxml_query_by' => 'ListID', 'sync_id' => qbd_payment_term_id, 'sync_full_name' => qbd_payment_term_full_name}
      # )
      #
      # sync_step.save
    end

    payment_term
  end

end
