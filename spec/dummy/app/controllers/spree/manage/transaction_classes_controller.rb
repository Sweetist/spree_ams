module Spree
  module Manage
    class TransactionClassesController < ResourceController
      def index
        @search = current_vendor.transaction_classes.ransack(params[:q])
        @txn_classes = @search.result.page(params[:page])
        respond_with(@txn_classes)
      end

      def new
        @txn_class = current_vendor.transaction_classes.new
        respond_with(@txn_class)
      end

      def create
        @txn_class = current_vendor.transaction_classes.new(txn_class_params)

        if @txn_class.save
          flash[:success] = "New Class has been saved"
          respond_to do |format|
  
            format.html {redirect_to manage_transaction_classes_path}
          end
        else
          respond_to do |format|
            format.html do
              flash.now[:errors] = @txn_class.errors.full_messages
              render :new
            end
          end
        end
      end

      def edit
        @txn_class = current_vendor.transaction_classes.find(params[:id])
        render :edit
      end

      def update
        @txn_class = current_vendor.transaction_classes.find(params[:id])

        if @txn_class.update(txn_class_params)
          flash[:success] = "Class has been updated"
          redirect_to manage_transaction_classes_path
        else
          flash.now[:errors] = @txn_class.errors.full_messages
          render :edit
        end
      end

      def destroy
        @txn_class = current_vendor.transaction_classes.find(params[:id])
        @txn_class.destroy

        respond_to do |format|
          format.js {}
          format.html {redirect_to manage_transaction_classes_path}
        end
      end

      private

      def txn_class_params
        params.require(:transaction_class).permit(
          :name,
          :parent_id
        )
      end
    end
  end
end
