class Spree::Admin::CompanyImagesController < Spree::Admin::ResourceController
  #before_action :load_data
  before_action :load_edit_data, except: :index
  before_action :load_index_data, only: :index

  create.before :set_viewable
  update.before :set_viewable

  private

    def location_after_destroy
      admin_company_company_images_url(@company)
    end

    def location_after_save
      admin_company_company_images_url(@company)
    end

    def load_index_data
      @company = Spree::Company.friendly.find(params[:company_id])
    end

    def load_edit_data
      @company = Spree::Company.friendly.find(params[:company_id])
    end

    def set_viewable
      @company_image.viewable_type = 'Spree::Company'
      @company_id = Spree::Company.friendly.find(params[:company_id])
      @company_image.viewable_id = @company_id.id
    end

end
