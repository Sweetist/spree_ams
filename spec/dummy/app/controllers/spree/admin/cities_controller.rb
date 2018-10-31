class Spree::Admin::CitiesController < Spree::Admin::ResourceController
  # belongs_to :state
  before_filter :load_data

  def index

    respond_with(@cities) do |format|
      format.html
      format.js  { render :partial => 'city_list.html.erb' }
    end
  end

  # def new
  #   @country = Spree::Country.find(params[:country_id])
  #   @state = Spree::State.find(params[:state_id])
  #   render :new
  # end

  def create
    @city = @state.cities.new(city_params)
    if @city.save
      flash[:success] = "#{@city.name} successfully added."
    else
      flash[:errors] = @city.errors.full_messages
    end
    redirect_to admin_country_state_cities_path(@country, @state)
  end

  def destroy
    @city = Spree::City.find(params[:id])
    @city.destroy!
    redirect_to admin_country_state_cities_path(@country, @state)
  end

  protected

  def location_after_save
    admin_country_state_cities_url(@country,@state)
  end

  def location_after_create
    admin_country_state_cities_url(@country,@state)
  end

  def collection
    super.order(:name)
  end

  def load_data
    @countries = Spree::Country.order(:name)
    @country = Spree::Country.find(params[:country_id])
    @states = Spree::State.order(:name)
    @state = Spree::State.find(params[:state_id])
    @cities = Spree::City.where(state_id: params[:state_id])
  end

  private

  def city_params
    params.require(:city).permit(:state_id, :country_id, :name)
  end
end
