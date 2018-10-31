Spree::Image.class_eval do
  clear_validators!

  validate :no_attachment_errors
  
  validates_attachment :attachment,
    :presence => true,
    :content_type => { :content_type => %w(image/jpeg image/jpg image/png image/gif image/png) },
    :size => { :less_than => 4.megabytes }
  
  # remove duplicate paperclip validation messages
  after_validation :clean_paperclip_errors

  private

  def clean_paperclip_errors
    errors.delete(:attachment)
  end
end