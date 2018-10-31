class Spree::Cust::UserImagesController < Spree::Cust::ResourceController
  before_action :load_edit_data, only: [:edit, :update]
  before_action :load_index_data, only: :index

  create.before :set_viewable
  update.before :set_viewable




  def new
    @user_image = Spree::UserImage.new
    @user = spree_current_user

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @user_image }
    end
  end

  def create
    @user = spree_current_user
    @user_image = spree_current_user.images.create(user_image_params)
    if @user_image.save
      flash[:success] = "Account image saved!"
      redirect_to my_profile_user_images_url
    else
      flash.now[:errors] = @user_image.errors.full_messages
      render :new
    end
  end

  def edit
    @user = spree_current_user
    @user_image = Spree::UserImage.find(params[:id])

      session[:id] = @user.id
      render :edit
    end

  def update
    @user = spree_current_user
    @user_image = Spree::UserImage.find(params[:id])
    session[:id] = @user_image.id
    if @user_image.update(user_image_params)
      flash[:success] = "Image updated!"
      redirect_to my_profile_user_images_path
    else
      flash.now[:errors] = @user_image.errors.full_messages
      render :edit
    end
  end

  def destroy
    @user = spree_current_user
    @user_image = Spree::UserImage.find(params[:id])

    if @user_image.destroy
      flash[:success] = "Image deleted!"
      redirect_to my_profile_user_images_path
    else
      flash.now[:errors] = @user_image.errors.full_messages
      render :edit
    end

  end

	protected

		def user_image_params
      params.require(:user_image).permit(
				:attachment,
				:alt,
        :viewable_type,
        :viewable_id
			)
		end

    def location_after_destroy
      my_profile_user_images_path
    end

    def location_after_save
      my_profile_user_images_path
    end
  private

    def load_index_data
      @user = spree_current_user
    end

    def load_edit_data
      @user = spree_current_user
			@user_image = Spree::UserImage.find(params[:id])
    end

    def set_viewable
      @user_image.viewable_type = 'Spree::User'
      @user_id = spree_current_user
      @user_image.viewable_id = @user_id.id
    end

end
