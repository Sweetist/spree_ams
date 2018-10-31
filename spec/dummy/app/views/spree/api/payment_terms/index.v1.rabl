object false
child(@payment_terms => :payment_terms) do
  extends "spree/api/payment_terms/show"
end

if @payment_terms.respond_to?(:num_pages)
  node(:count) { @payment_terms.count }
  node(:current_page) { params[:page] || 1 }
  node(:pages) { @payment_terms.num_pages }
end
