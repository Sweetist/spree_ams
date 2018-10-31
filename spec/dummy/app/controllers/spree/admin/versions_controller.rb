class Spree::Admin::VersionsController < Spree::Admin::ResourceController
  before_action :load_version, only: :show

  def show
    respond_to do |format|
      format.json do
        render json: JSON.pretty_generate(@version.as_json)
      end
    end
  end

  private

  def load_version
    @version = Spree::Version.find(params[:id])
  end
end
