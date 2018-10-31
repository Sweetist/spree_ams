Spree::Admin::SearchController.class_eval do
  def companies
    if params[:ids]
      @companies = Spree::Company.where(id: params[:ids].split(",").flatten)
    else
      @companies = Spree::Company.ransack(params[:q]).result
    end

    @companies = @companies.page(params[:page]).per(params[:per_page])
    expires_in 15.minutes, public: true
    headers['Surrogate-Control'] = "max-age=#{15.minutes}"
  end
end
