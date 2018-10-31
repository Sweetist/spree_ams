object false
child(@customers => :customers) do
  extends "spree/api/customers/show"
end

if @customers.respond_to?(:num_pages)
  node(:count) { @customers.count }
  node(:current_page) { params[:page] || 1 }
  node(:pages) { @customers.num_pages }
end
