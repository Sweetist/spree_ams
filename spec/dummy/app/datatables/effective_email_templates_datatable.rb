class EffectiveEmailTemplatesDatatable < Effective::Datatable
  datatable do
    order :subject, :asc

    col :id, visible: false
    col :slug
    col :subject
    col :from
    col :cc, visible: false, label: 'CC'
    col :bcc, visible: false, label: 'BCC'
    col :body, visible: false

    actions_col partial: 'actions', partial_as: 'email_template'
  end

  collection do
    # scope to current vendor
    Spree::EmailTemplate.where(vendor_id: current_vendor.id)
  end
end
