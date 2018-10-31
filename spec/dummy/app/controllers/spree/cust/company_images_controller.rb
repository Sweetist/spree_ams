class Spree::Cust::CompanyImagesController < Spree::Cust::ResourceController

  before_action :load_edit_data, only: [:edit, :update]
  before_action :load_index_data, only: [:index, :new]

  create.before :set_viewable
  update.before :set_viewable


  def new
    @account_image = Spree::CompanyImage.new

    respond_to do |format|
      format.html
      format.json { render json: @account_image }
    end
  end

  def create
    @account_image = spree_current_user.company.images.create(company_image_params)
    if @account_image.save
      flash[:success] = "Account image saved!"
      redirect_to my_company_company_images_url
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
      flash[:success] = "Account image updated!"
      redirect_to my_company_company_images_url(@account_image)
    else
      flash.now[:errors] = @account_image.errors.full_messages
      render :edit
    end
  end

  def destroy
    @account_image = Spree::CompanyImage.find(params[:id])

    if @account_image.destroy
      flash[:success] = "Image deleted"
      redirect_to my_company_company_images_url
    else
      flash.now[:errors] = @account_image.errors.full_messages
      render :edit
    end

  end

	protected

  def company_image_params
    params.require(:company_image).permit(
    	:attachment,
    	:alt,
      :viewable_type,
      :viewable_id
    )
  end

  private

  def location_after_destroy
    account_account_images_url
  end

  def location_after_save
    account_account_images_url
  end

  def load_index_data
    @account = spree_current_user.company
  end

  def load_edit_data
    @account = spree_current_user.company
		@account_image = Spree::CompanyImage.find(params[:id])
  end

  def set_viewable
    @account_image.viewable_type = 'Spree::Company'
    @account_id = spree_current_user.company
    @account_image.viewable_id = @account_id.id
  end

end
