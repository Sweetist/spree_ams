class Spree::Manage::ProductImportsController < Spree::Manage::BaseController
  before_action :ensure_write_permission, only: [:index, :new, :create, :show, :destroy]

  def index
    @imports = current_vendor.product_imports.order("created_at desc")
  end

  def new
    @product_import = current_vendor.product_imports.new
  end

  def create
    @product_import = current_vendor.product_imports.new(product_import_params)
    if @product_import.save
      Sidekiq::Client.push('class' => ProductImportWorker, 'queue' => 'imports', 'args' => [@product_import.id])
      redirect_to manage_product_imports_path, flash: { success: "Import has been queued and will be processed shortly!" }
    else
      flash.now[:errors] = @product_import.errors.full_messages
      render :new
    end
  end

  def show
    @product_import = current_vendor.product_imports.find(params[:id])
    respond_with(@product_import)
  end

  def verify
    @product_import = current_vendor.product_imports.find(params[:product_import_id])
    Sidekiq::Client.push('class' => ProductImportWorker, 'queue' => 'imports', 'args' => [@product_import.id])
    redirect_to manage_product_imports_path, flash: { success: "Import has been queued for verification and will be processed shortly!" }
  end

  def import
    if @product_import == 2
      @product_import.update_columns(status: 4) #set to 'Queued' if verified
    end
    @product_import = current_vendor.product_imports.find(params[:product_import_id])
    Sidekiq::Client.push('class' => ProductImportWorker, 'queue' => 'imports', 'args' => [@product_import.id])
    redirect_to manage_product_imports_path, flash: { success: "Import has been queued for import and will be processed shortly!" }

  end

  def destroy
    @product_import = current_vendor.product_imports.find(params[:id])
    @product_import.destroy
    redirect_to manage_product_imports_path, flash: { success: "Import has been deleted!" }
  end

  private

  def product_import_params
    params.require(:product_import).permit(:file, :encoding, :delimer, :replace, :proceed, :proceed_verified)
  end

  def ensure_write_permission
    if current_spree_user.cannot_read?('catalog', 'products')
      flash[:error] = 'You do not have permission to view products'
      redirect_to manage_path
    elsif current_spree_user.cannot_write?('catalog', 'products')
      flash[:error] = 'You do not have permission to edit products'
      redirect_to manage_products_path
    end
  end


end
