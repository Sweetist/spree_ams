module Spree
  module Manage
    class ImagesController < ResourceController
      before_action :ensure_read_permission, only: [:index]
      before_action :ensure_write_permission, only: [:new, :create, :edit, :update, :destroy]

      before_action :load_data

      create.before :set_viewable
      update.before :set_viewable

      def new
        @image = Spree::Image.new

        respond_to do |format|
          format.html # new.html.erb
          format.json { render json: @image }
        end
      end


      def create
        @image = @product.variants_including_master.find_by_id(image_params['viewable_id']).images.new(image_params)
        if @image.save
          flash[:success] = "Image saved"
         redirect_to manage_product_images_url(@product)
        else
          flash.now[:errors] = @image.errors.full_messages
          render :new
        end
      end

      def edit
        @image = Spree::Image.find(params[:id])

        session[:id] = @product.id
        render :edit
      end

      def update
        @image = Spree::Image.find(params[:id])
        session[:id] = @image.id
        if @image.update(image_params)
          flash[:success] = "Image updated"
          redirect_to manage_product_images_url(@product)
        else
          flash.now[:errors] = @image.errors.full_messages
          render :edit
        end
      end

      def index
      end

      def destroy

        @image = Spree::Image.find(params[:id])

        if @image.destroy
          flash[:success] = "Image deleted"
          redirect_to manage_product_images_url(@product)
        else
          flash.now[:errors] = @image.errors.full_messages
          render :edit
        end

       end

      private

        def image_params
          params.require(:image).permit(
            :attachment,
            :alt,
            :viewable_type,
            :viewable_id
          )
        end

        def ensure_read_permission
          if current_spree_user.cannot_read?('catalog', 'products')
            flash[:error] = 'You do not have permission to view product images'
            redirect_to manage_path
          end
        end

        def ensure_write_permission
          if current_spree_user.cannot_read?('catalog', 'products')
            flash[:error] = 'You do not have permission to view product images'
            redirect_to manage_path
          elsif current_spree_user.cannot_write?('catalog', 'products')
            flash[:error] = 'You do not have permission to edit product images'
            redirect_to manage_products_path
          end
        end

        def load_data
          @product = Product.friendly.find(params[:product_id])
          @variants = @product.variants.collect do |variant|
            [variant.sku_and_options_text, variant.id]
          end
          @variants.insert(0, [Spree.t(:all), @product.master.id])
        end

        def set_viewable
          @image.viewable_type = 'Spree::Variant'
          @image.viewable_id = params[:image][:viewable_id]
        end

    end
  end
end
