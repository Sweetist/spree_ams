object false
child(@customer_types => :customer_types) do
  extends "spree/api/customer_types/show"
end

if @customer_types.respond_to?(:num_pages)
  node(:count) { @customer_types.count }
  node(:current_page) { params[:page] || 1 }
  node(:pages) { @customer_types.num_pages }
end
