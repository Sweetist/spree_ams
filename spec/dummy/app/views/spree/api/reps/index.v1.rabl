object false
child(@reps => :reps) do
  extends "spree/api/reps/show"
end

if @reps.respond_to?(:num_pages)
  node(:count) { @reps.count }
  node(:current_page) { params[:page] || 1 }
  node(:pages) { @reps.num_pages }
end
