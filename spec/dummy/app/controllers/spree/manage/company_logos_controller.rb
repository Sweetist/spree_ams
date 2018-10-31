class Spree::Manage::CompanyLogosController < Spree::Manage::ResourceController
  before_action :load_account
  before_action :load_edit_data, only: [:edit, :update]
  before_action :ensure_read_permission, only: [:index]
  before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]

  create.before :set_viewable
  update.before :set_viewable

  def index
  end

  def new
    @logo = Spree::CompanyLogo.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @logo }
    end
  end

  def create
    @logo = spree_current_user.company.logos.create(company_logo_params)
    if @logo.save
      flash[:success] = "Logo saved"
      redirect_to manage_account_logos_url
    else
      flash.now[:errors] = @logo.errors.full_messages
      render :new
    end
  end

  def edit
    @logo = Spree::CompanyLogo.find(params[:id])

    session[:id] = @account.id
    render :edit
  end

  def update
    @logo = Spree::CompanyLogo.find(params[:id])
    session[:id] = @logo.id
    if @logo.update(company_logo_params)
      flash[:success] = "Account logo updated"
      redirect_to manage_account_logos_url
    else
      flash.now[:errors] = @logo.errors.full_messages
      render :edit
    end
  end

  def destroy
    @logo = Spree::CompanyLogo.find(params[:id])

    if @logo.destroy
      flash[:success] = "Image deleted!"
      redirect_to manage_account_logos_url
    else
      flash.now[:errors] = @logo.errors.full_messages
      render :edit
    end
  end

  private

  def company_logo_params
    params.require(:company_logo).permit(
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
    @logo = Spree::CompanyLogo.find(params[:id])
  end

  def set_viewable
    @logo.viewable_type = 'Spree::Company'
    @logo.viewable_id = spree_current_user.company_id
  end

  def ensure_read_permission
    if current_spree_user.cannot_read?('company')
      flash[:error] = 'You do not have permission to view company logos'
      redirect_to manage_path
    end
  end

  def ensure_write_permission
    if current_spree_user.cannot_read?('company')
      flash[:error] = 'You do not have permission to view company logos'
      redirect_to manage_path
    elsif current_spree_user.cannot_write?('company')
      flash[:error] = 'You do not have permission to edit company logos'
      redirect_to manage_account_logos_path
    end
  end
end
