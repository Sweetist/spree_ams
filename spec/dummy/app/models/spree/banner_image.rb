# == Schema Information
#
# Table name: spree_assets
#
#  id                      :integer          not null, primary key
#  viewable_id             :integer
#  viewable_type           :string
#  attachment_width        :integer
#  attachment_height       :integer
#  attachment_file_size    :integer
#  position                :integer
#  attachment_content_type :string
#  attachment_file_name    :string
#  type                    :string(75)
#  attachment_updated_at   :datetime
#  alt                     :text
#  created_at              :datetime
#  updated_at              :datetime
#

class Spree::BannerImage < Spree::Asset
  validate :no_attachment_errors

  has_attached_file :attachment,
                    styles: { mini: '150x30', small: '750x150>', medium: '1000x200>', large: '1200x240>', xlarge: '1400x280>' },
                    default_style: :xlarge,
                    url: '/spree/companies/banner_images/:id/:style/:basename.:extension',
                    path: ':rails_root/public/spree/companies/banner_images/:id/:style/:basename.:extension',
                    convert_options: { all: '-strip -auto-orient -colorspace sRGB' }
  validates_attachment :attachment,
    :presence => true,
    :content_type => { :content_type => %w(image/jpeg image/jpg image/png image/gif) },
    :size => { :less_than => 4.megabytes }

  # save the w,h of the original image (from which others can be calculated)
  # we need to look at the write-queue for images which have not been saved yet
  after_post_process :find_dimensions

  # remove duplicate paperclip validation messages
  after_validation :clean_paperclip_errors

  #used by admin products autocomplete
  def mini_url
    attachment.url(:mini, false)
  end

  def find_dimensions
    temporary = attachment.queued_for_write[:original]
    filename = temporary.path unless temporary.nil?
    filename = attachment.path if filename.blank?
    geometry = Paperclip::Geometry.from_file(filename)
    self.attachment_width  = geometry.width
    self.attachment_height = geometry.height
  end

  # if there are errors from the plugin, then add a more meaningful message
  def no_attachment_errors
    unless attachment.errors.empty?
      # uncomment this to get rid of the less-than-useful interim messages
      # errors.clear
      errors.add :attachment, "Paperclip returned errors for file '#{attachment_file_name}' - check ImageMagick installation or image source file."
      false
    end
  end

  private

  def clean_paperclip_errors
    errors.delete(:attachment)
  end
end
