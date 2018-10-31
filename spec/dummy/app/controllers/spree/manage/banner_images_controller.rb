class Spree::Manage::BannerImagesController < Spree::Manage::ResourceController
  before_action :load_account
  before_action :load_edit_data, only: [:edit, :update, :destroy]
  before_action :ensure_read_permission, only: [:index]
  before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]

  create.before :set_viewable
  update.before :set_viewable

  def index
    @banner_images = @account.banner_images
  end

  def new
    @banner_image = Spree::BannerImage.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @banner_image }
    end
  end

  def create
    @banner_image = spree_current_user.company.banner_images.create(banner_image_params)
    if @banner_image.save
      flash[:success] = "Banner image saved"
      redirect_to manage_account_banner_images_url
    else
      flash.now[:errors] = @banner_image.errors.full_messages
      render :new
    end
  end

  def edit
    render :edit
  end

  def update
    if @banner_image.update(banner_image_params)
      flash[:success] = "Account banner image updated"
      redirect_to manage_account_banner_images_url
    else
      flash.now[:errors] = @banner_image.errors.full_messages
      render :edit
    end
  end

  def destroy
    if @banner_image.destroy
      flash[:success] = "Image deleted!"
      redirect_to manage_account_banner_images_url
    else
      flash.now[:errors] = @banner_image.errors.full_messages
      render :edit
    end
  end

  private

  def banner_image_params
    params.require(:banner_image).permit(
    :attachment,
    :alt,
    :viewable_type,
    :viewable_id
    )
  end

  def load_account
    @account = spree_current_user.company
  end

  def load_edit_data
    @banner_image = @account.banner_images.find(params[:id])
  end

  def set_viewable
    @banner_image.viewable_type = 'Spree::Company'
    @banner_image.viewable_id = spree_current_user.company_id
  end

  def ensure_read_permission
    if current_spree_user.cannot_read?('company')
      flash[:error] = 'You do not have permission to view company banner images'
      redirect_to manage_path
    end
  end

  def ensure_write_permission
    if current_spree_user.cannot_read?('company')
      flash[:error] = 'You do not have permission to view company banner images'
      redirect_to manage_path
    elsif current_spree_user.cannot_write?('company')
      flash[:error] = 'You do not have permission to edit company banner images'
      redirect_to manage_account_banner_images_path
    end
  end
end
