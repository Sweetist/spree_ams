module Spree
  module Manage
    class InventoriesController < Spree::Manage::BaseController
      before_action :ensure_subscription_includes, only: [:show]
      before_action :ensure_read_permission, only: [:show]

      def show
        @vendor = current_vendor
        @categories = @vendor.taxons.where.not(parent_id: nil).order(:name)
        @stock_locations = @vendor.stock_locations
        params[:q] ||= {}
        @open_search = params[:q].except('s').any?{|k,v| v.present?}

        if params.fetch(:q, {}).fetch(:include_unavailable, false).to_bool
          params[:q][:include_unavailable] = true
          params[:q][:available_on_lt] = nil
        else
          params[:q][:available_on_lt] = Time.current
        end
        products_with_variants_ids = Spree::Product.joins(:variants).distinct.ids
        unless products_with_variants_ids.empty?
          @search = Spree::Variant.joins(:product).where('spree_products.vendor_id = ?',@vendor.id)
                                                  .where('(spree_variants.is_master = ? and spree_variants.product_id in (?)) or (spree_variants.is_master = ? and spree_variants.product_id not in (?))',
                                                          false, products_with_variants_ids, true, products_with_variants_ids)
                                                  .includes(:product, stock_items: :stock_location).inventory
        else
          @search = Spree::Variant.joins(:product).where('spree_products.vendor_id = ?',@vendor.id)
                                                  .includes(:product, stock_items: :stock_location).inventory
        end

        low_stock = params[:q][:low_stock]
        params[:q][:low_stock] = nil
        if low_stock.to_bool
          @search = @search.low_stock
        end
        unless params[:q][:include_inactive].to_bool
          @search = @search.active
        end
        @search = @search.ransack(params[:q])
        @search.sorts = @vendor.cva.try(:variant_default_sort) if @search.sorts.empty?
        @variants = @search.result.page(params[:page])
        params[:q][:low_stock] = low_stock unless low_stock.nil?

        render :show
      end

      def download_csv
        vendor = current_company
        variants = current_company.showable_variants
                                  .inventory.order(:full_display_name)
        update_headers(vendor)

        self.response_body = Enumerator.new do |yielder|
          yielder << first_line_head(vendor).to_csv
          yielder << second_line_head(vendor).to_csv
          variants.each do |variant|
            yielder << variant.line_for_csv.to_csv
          end
        end
        response.status = 200
      end

      private

      def ensure_read_permission
        unless current_spree_user.can_read?('basic_options', 'inventory')
          flash[:error] = "You do not have permission to view inventory"
          redirect_to manage_path
        end
      end

      def ensure_subscription_includes
        unless current_company.subscription_includes?('inventory')
          render :show_upgrade and return
        end
      end

      def update_headers(vendor)
        headers.delete('Content-Length')
        headers['Cache-Control'] = 'no-cache'
        headers['Content-Type'] = 'text/csv'
        headers['Content-Disposition'] = "attachment; filename=\"#{Time.current.in_time_zone(vendor.try(:time_zone)).strftime('%Y-%m-%d')}_inventory.csv\""
        headers['X-Accel-Buffering'] = 'no'
      end

      def first_line_head(vendor)
        line_head = ['', '', '']
        vendor.stock_locations.active.each do |location|
          line_head += [location.name, '', '']
        end
        line_head += ['Total', '', '']
      end

      def second_line_head(vendor)
        line_head = ['Name', 'SKU', 'Pack Size']
        column_count = vendor.stock_locations.active.try(:count) + 1
        column_count.times do
          line_head += ['On Hand', 'Available', 'Committed']
        end
        line_head
      end
    end
  end
end
