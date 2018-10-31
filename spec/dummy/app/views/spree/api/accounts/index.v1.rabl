object false
child(@accounts => :accounts) do
  extends "spree/api/accounts/show"
end

if @accounts.respond_to?(:num_pages)
  node(:count) { @accounts.count }
  node(:current_page) { params[:page] || 1 }
  node(:pages) { @accounts.num_pages }
end
