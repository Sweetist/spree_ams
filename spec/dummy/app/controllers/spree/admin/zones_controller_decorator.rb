Spree::Admin::ZonesController.class_eval do
  before_filter :load_cities, :except => [:index]

protected

  def load_cities
    @cities = Spree::City.order(:name)
  end

end
