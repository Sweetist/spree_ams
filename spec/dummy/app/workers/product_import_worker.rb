class ProductImportWorker
  include Sidekiq::Worker

  def perform(import_id)
    import = Spree::ProductImport.find(import_id)
    if import.status == 0
      import.verify!
    elsif import.status == 2 || import.status == 4 #'Verified' or 'Queued'
      import.import!
    end
    import.save
  rescue ActiveRecord::RecordNotFound
    true # moving on if import has been removed from DB
  end

end
