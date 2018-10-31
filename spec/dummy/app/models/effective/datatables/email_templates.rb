module Effective
  module Datatables
    class EmailTemplates < Effective::Datatable
      datatable do
        default_order :subject, :asc

        table_column :id, visible: false
        table_column :slug
        table_column :subject
        table_column :from
        table_column :cc, sortable: false, visible: false, label: 'CC'
        table_column :bcc, sortable: false, visible: false, label: 'BCC'
        table_column :body, sortable: false, visible: false
        table_column :actions, sortable: false, partial: 'actions'
      end

      def collection
        current_vendor.email_templates
      end
    end
  end
end
