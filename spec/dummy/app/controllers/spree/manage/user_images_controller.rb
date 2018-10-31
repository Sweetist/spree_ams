class Spree::Manage::UserImagesController < Spree::Manage::ResourceController
  before_action :load_edit_data, only: [:edit, :update]
  before_action :load_index_data, only: :index

  before_action :ensure_read_permission, only: [:index]
  before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]

  create.before :set_viewable
  update.before :set_viewable

  def new
    @user_image = Spree::UserImage.new
    @user = spree_current_user.company.users.find(params[:user_id])

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @user_image }
    end
  end

  def create
    @user = spree_current_user.company.users.find(params[:user_id])
    @user_image = spree_current_user.images.create(user_image_params)
    if @user_image.save
      flash[:success] = "Profile image saved"
      redirect_to manage_account_user_user_images_path(@user)
    else
      flash.now[:errors] = @user_image.errors.full_messages
      render :new
    end
  end

  def edit
    @user = spree_current_user.company.users.find(params[:user_id])
    @user_image = Spree::UserImage.find(params[:id])

    session[:id] = @user.id
    render :edit
  end

  def update
    @user = spree_current_user.company.users.find(params[:user_id])
    @user_image = Spree::UserImage.find(params[:id])
    session[:id] = @user_image.id
    if @user_image.update(user_image_params)
      flash[:success] = "Profile image updated"
      redirect_to manage_account_user_user_images_path(@user)
    else
      flash.now[:errors] = @user_image.errors.full_messages
      render :edit
    end
  end

  def destroy
    @user = spree_current_user.company.users.find(params[:user_id])
    @user_image = Spree::UserImage.find(params[:id])

    if @user_image.destroy
      flash[:success] = "Profile image deleted"
      redirect_to manage_account_user_user_images_path(@user)
    else
      flash.now[:errors] = @user_image.errors.full_messages
      render :edit
    end
  end


  private
  def user_image_params
    params.require(:user_image).permit(
    :attachment,
    :alt,
    :viewable_type,
    :viewable_id
    )
  end

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

  def ensure_read_permission
    return true if current_spree_user.id.to_s == params[:user_id]
    if current_spree_user.cannot_read?('basic_options', 'users')
      flash[:error] = 'You do not have permission to view users'
      redirect_to manage_path
    end
  end

  def ensure_write_permission
    return true if current_spree_user.id.to_s == params[:user_id]
    if current_spree_user.cannot_read?('basic_options', 'users')
      flash[:error] = 'You do not have permission to view users'
      redirect_to manage_path
    elsif current_spree_user.cannot_write?('basic_options', 'users')
      flash[:error] = 'You do not have permission to edit users'
      redirect_to manage_account_user_user_images_path(params[:user_id])
    end
  end

end
