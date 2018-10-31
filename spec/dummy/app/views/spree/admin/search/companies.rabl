object false
node(:count) { @companies.count }
node(:total_count) { @companies.total_count }
node(:current_page) { params[:page] ? params[:page].to_i : 1 }
node(:per_page) { params[:per_page] || Kaminari.config.default_per_page }
node(:pages) { @companies.num_pages }
child(@companies => :companies) do
  attributes :id, :name
end
