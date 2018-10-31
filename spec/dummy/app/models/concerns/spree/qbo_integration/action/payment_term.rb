module Spree::QboIntegration::Action::PaymentTerm
  def qbo_synchronize_payment_term(payment_term_id)
    term = Spree::PaymentTerm.find(payment_term_id)
    payment_term = term.to_integration(
        self.integration_item.integrationable_options_for(term)
      )

    service = self.integration_item.qbo_service('Term')

    match = self.integration_item.integration_sync_matches.find_or_create_by(
      integration_syncable_id: payment_term.fetch(:id),
      integration_syncable_type: 'Spree::PaymentTerm'
    )
    if match.sync_id
      qbo_term = service.fetch_by_id(match.sync_id)
      qbo_update_term(qbo_term, payment_term, service)
    else
      qbo_term = service.query("select * from Term where Name='#{self.qbo_safe_string(payment_term.fetch(:name))}'").first
      if qbo_term
        # we have a match, save ID
        match.sync_id = qbo_term.id
        match.sync_type = qbo_term.class.to_s
        match.save
        qbo_update_term(qbo_term, payment_term, service)
      elsif self.integration_item.qbo_create_related_objects
        # try to create
        qbo_new_term = qbo_term_to_qbo(Quickbooks::Model::Term.new, payment_term)

        response = service.create(qbo_new_term)
        match.sync_id = response.id
        match.sync_type = response.class.to_s
        match.save
        { status: 10, log: "#{payment_term.fetch(:name_for_integration)} => Pushed." }
      else
        { status: -1, log: "#{payment_term.fetch(:name_for_integration)} => Unable to find Match for #{name}" }
      end
    end
  end

  def qbo_update_term(qbo_term, payment_term, service)
    qbo_updated_term = qbo_term_to_qbo(qbo_term, payment_term)
    if self.integration_item.qbo_overwrite_conflicts_in == 'quickbooks'
      service.update(qbo_updated_term)
      { status: 10, log: "#{payment_term.fetch(:name_for_integration)} category => Match updated in QBO." }
    elsif self.integration_item.qbo_overwrite_conflicts_in == 'sweet'
      { status: 3, log: "#{payment_term.fetch(:name_for_integration)} category => Not currently supported"}
    else
      { status: 10, log: "#{payment_term.fetch(:name_for_integration)} category => No conflict resolution." }
    end
  end

  def qbo_term_to_qbo(qbo_term, payment_term)
    qbo_term.name = payment_term.fetch(:name)
    qbo_term.due_days = payment_term.fetch(:due_in_days).to_i

    qbo_term
  end
end
