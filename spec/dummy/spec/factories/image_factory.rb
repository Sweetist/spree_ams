FactoryGirl.define do
  factory :image, class: Spree::Image do
    attachment { File.new(Spree::Core::Engine.root + "spec/fixtures" + 'thinking-cat.jpg') }
  end

  factory :logo, class: Spree::Image do
    attachment { Rack::Test::UploadedFile.new(Spree::Core::Engine.root + "spec/fixtures" + 'thinking-cat.jpg', 'image/jpg') }
    type 'Spree::CompanyLogo'
  end

  factory :company_image, class: Spree::Image do
    attachment { Rack::Test::UploadedFile.new(Spree::Core::Engine.root + "spec/fixtures" + 'thinking-cat.jpg', 'image/jpg') }
    type 'Spree::CompanyImage'
  end

  factory :product_image, class: Spree::Image do
    attachment { Rack::Test::UploadedFile.new(Spree::Core::Engine.root + "spec/fixtures" + 'thinking-cat.jpg', 'image/jpg') }
    type 'Spree::Image'
  end

  factory :user_image, class: Spree::Image do
    attachment { Rack::Test::UploadedFile.new(Spree::Core::Engine.root + "spec/fixtures" + 'thinking-cat.jpg', 'image/jpg') }
    type 'Spree::UserImage'
  end
end
