Deface::Override.new(:virtual_path => 'spree/admin/taxonomies/_form',
  :name => 'add_vendor_to_taxonomy_form',
  :insert_after => "[data-hook='admin_inside_taxonomy_form']",
  :text => "<div data-hook='taxonomy_vendor'>
            <%= f.field_container :vendor, :class => ['form-group'] do %>
            <%= f.label :vendor_id, Spree.t(:vendors) %>
            <%= f.collection_select(:vendor_id, Spree::Company.all, :id, :name, { :include_blank => Spree.t('match_choices') }, { :class => 'select2' }) %>
            <%= f.error_message_on :vendors %>
            <% end %>
            </div>"
  )
