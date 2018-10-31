module EmailTemplatesHelper
  def datatable_of(description_of_objects, datatable)
    if datatable.nil?
      content_tag(:p, "Please use Effective Datatables gem")
    elsif datatable.collection.length > 0
      render_datatable(datatable)
    else
      content_tag(:p, "There are no email templates")
    end
  end

  def email_template_form_url( email_template )
    if email_template.new_record?
      manage_email_templates_path
    else
      manage_email_template_path( email_template )
    end
  end
end
