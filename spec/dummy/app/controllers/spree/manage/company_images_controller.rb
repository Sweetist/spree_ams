class Spree::Manage::CompanyImagesController < Spree::Manage::ResourceController
  before_action :load_edit_data, only: [:edit, :update]
  before_action :load_account

  before_action :ensure_read_permission, only: [:index]
  before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]

  create.before :set_viewable
  update.before :set_viewable

  def new
    @vendor = current_vendor
    @account_image = Spree::CompanyImage.new

    respond_to do |format|
      format.html
      format.json { render json: @account_image }
    end
  end

  def create
    @vendor = current_vendor
    @account_image = spree_current_user.company.images.create(company_image_params)
    if @account_image.save
      flash[:success] = "Account image saved"
      redirect_to manage_account_account_images_url
    else
      flash.now[:errors] = @account_image.errors.full_messages
      render :new
    end
  end

  def edit
    @account_image = Spree::CompanyImage.find(params[:id])

    session[:id] = @account.id
    render :edit
  end

  def update
    @account_image = Spree::CompanyImage.find(params[:id])
    session[:id] = @account_image.id
    if @account_image.update(company_image_params)
      flash[:success] = "Account image updated"
      redirect_to manage_account_account_images_url
    else
      flash.now[:errors] = @account_image.errors.full_messages
      render :edit
    end
  end

  def destroy
    @vendor = current_vendor
    @account_image = Spree::CompanyImage.find(params[:id])

    if @account_image.destroy
      flash[:success] = "Image deleted!"
      redirect_to manage_account_account_images_url
    else
      flash.now[:errors] = @account_image.errors.full_messages
      render :edit
    end
  end


  private

  def company_image_params
    params.require(:company_image).permit(
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
    @account_image = Spree::CompanyImage.find(params[:id])
  end

  def set_viewable
    @account_image.viewable_type = 'Spree::Company'
    @account_image.viewable_id = spree_current_user.company_id
  end

  def ensure_read_permission
    if current_spree_user.cannot_read?('company')
      flash[:error] = 'You do not have permission to view company images'
      redirect_to manage_path
    end
  end

  def ensure_write_permission
    if current_spree_user.cannot_read?('company')
      flash[:error] = 'You do not have permission to view company images'
      redirect_to manage_path
    elsif current_spree_user.cannot_write?('company')
      flash[:error] = 'You do not have permission to edit company images'
      redirect_to manage_account_account_images_path
    end
  end

end
