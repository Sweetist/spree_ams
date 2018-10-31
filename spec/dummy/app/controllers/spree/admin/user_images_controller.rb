class Spree::Admin::UserImagesController < Spree::Admin::ResourceController
  #before_action :load_data
  before_action :load_edit_data, except: :index
  before_action :load_index_data, only: :index

  create.before :set_viewable
  update.before :set_viewable

  private

    def location_after_destroy
      admin_user_user_images_url(@user)
    end

    def location_after_save
      admin_user_user_images_url(@user)
    end

    def load_index_data
      @user = Spree::User.find(params[:user_id])
    end 

    def load_edit_data
      @user = Spree::User.find(params[:user_id])
    end

    def set_viewable
      @user_image.viewable_type = 'Spree::User'
      @user_id = Spree::User.find(params[:user_id])
      @user_image.viewable_id = @user_id.id
    end
  
end
