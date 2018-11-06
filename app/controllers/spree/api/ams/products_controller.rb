module Spree
  module Api
    module Ams
      class ProductsController < Spree::Api::ProductsController
        include Serializable
        include Requestable

        def create
          authorize! :create, Spree::Product
          params[:product][:available_on] ||= Time.now
          set_up_shipping_category

          options = { variants_attrs: variants_params, options_attrs: option_types_params }
          options[:vendor_id] = current_vendor.id
          @product = Spree::Core::Importer::Product.new(nil, product_params, options).create

          if @product.persisted?
            respond_with(@product, :status => 201, :default_template => :show)
          else
            invalid_resource!(@product)
          end
        end

        def product_scope
          scope = super
          if params[:taxon_id]
            taxon = Taxon.friendly.find(params[:taxon_id])
            scope = scope.joins(:classifications).where("#{Spree::Classification.table_name}.taxon_id" => taxon.self_and_descendants.pluck(:id))
          end
          scope
        end
      end
    end
  end
end
