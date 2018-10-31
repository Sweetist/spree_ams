module Spree
  module Manage
    class OrderRulesController < Spree::Manage::BaseController
      before_action :ensure_read_permission, only: [:index, :show]
      before_action :ensure_write_permission, except: [:index, :show]
      before_action :set_spree_order_rule, except: %i[index new create]

      # GET /spree/order_rules
      # GET /spree/order_rules.json
      def index
        @order_rules = current_vendor.order_rules
      end

      # GET /spree/order_rules/1
      # GET /spree/order_rules/1.json
      def show
      end

      # GET /spree/order_rules/new
      def new
        @order_rule = current_vendor.order_rules.new
      end

      # GET /spree/order_rules/1/edit
      def edit
      end

      # POST /spree/order_rules
      # POST /spree/order_rules.json
      def create
        @order_rule = current_vendor.order_rules.new(spree_order_rule_params)
        respond_to do |format|
          if @order_rule.save
            format.html { redirect_to manage_order_rules_url, notice: 'Order rule was successfully created.' }
            format.json { render :show, status: :created, location: @order_rule }
          else
            format.html do
              flash.now[:errors] = @order_rule.errors.full_messages
              render :new
            end
            format.json { render json: @order_rule.errors, status: :unprocessable_entity }
          end
        end
      end

      # PATCH/PUT /spree/order_rules/1
      # PATCH/PUT /spree/order_rules/1.json
      def update
        respond_to do |format|
          if @order_rule.update(spree_order_rule_params)
            format.html { redirect_to manage_order_rules_url, notice: 'Order rule was successfully updated.' }
            format.json { render :show, status: :ok, location: @order_rule }
          else
            format.html do
              flash.now[:errors] = @order_rule.errors.full_messages
              render :edit
            end
            format.json { render json: @order_rule.errors, status: :unprocessable_entity }
          end
        end
      end

      # DELETE /spree/order_rules/1
      # DELETE /spree/order_rules/1.json
      def destroy
        @order_rule.destroy
        respond_to do |format|
          format.html { redirect_to manage_order_rules_url, notice: 'Order rule was successfully destroyed.' }
          format.json { head :no_content }
        end
      end

      def toggle_active
        @order_rule.update_column :active, params[:active]

        render nothing: true
      end

      private

      def order_rule_url(order_rule)
        manage_order_rule_url(order_rule)
      end

      # Use callbacks to share common setup or constraints between actions.
      def set_spree_order_rule
        @vendor = current_vendor
        @order_rule = current_vendor.order_rules.find(params[:id])
      end

      # Never trust parameters from the scary internet, only allow the white list through.
      def spree_order_rule_params
        params.require(:order_rule).permit(:vendor_id, :rule_type, :value, :active, taxon_ids: [])
      end

      def ensure_read_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = "You do not have permission to view order rules"
          redirect_to manage_path
        end
      end

      def ensure_write_permission
        if current_spree_user.cannot_read?('company')
          flash[:error] = "You do not have permission to view order rules"
          redirect_to manage_path
        elsif current_spree_user.cannot_write?('company')
          flash[:error] = "You do not have permission to edit order rules"
          redirect_to manage_path
        end
      end
    end
  end
end
