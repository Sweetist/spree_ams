# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path
Rails.application.config.assets.precompile += %w( ckeditor/* )
Rails.application.config.assets.precompile += %w( spree/sweet-frontend/frontend.js )
Rails.application.config.assets.precompile += %w( spree/sweet-frontend/manage/manage_all.js )
Rails.application.config.assets.precompile += %w( spree/sweet-frontend/cust/cust_all.js )
Rails.application.config.assets.precompile += %w( spree/backend/all.js )

Rails.application.config.assets.precompile += %w( sweet-frontend.css )
Rails.application.config.assets.precompile += %w( sweet-session.css )
Rails.application.config.assets.precompile += %w( sweet-frontend/layouts/layout/themes/blue.css )
Rails.application.config.assets.precompile += %w( sweet-frontend/layouts/layout/themes/darkblue.css )
Rails.application.config.assets.precompile += %w( sweet-frontend/layouts/layout/themes/darkred.css )
Rails.application.config.assets.precompile += %w( sweet-frontend/layouts/layout/themes/default.css )
Rails.application.config.assets.precompile += %w( sweet-frontend/layouts/layout/themes/grey.css )
Rails.application.config.assets.precompile += %w( sweet-frontend/layouts/layout/themes/light.css )
Rails.application.config.assets.precompile += %w( sweet-frontend/layouts/layout/themes/light2.css )
Rails.application.config.assets.precompile += %w( sweet-frontend/layouts/layout/themes-customer/darkblue.css )
Rails.application.config.assets.precompile += %w( sweet-frontend/layouts/layout/themes-customer/darkred.css )
Rails.application.config.assets.precompile += %w( sweet-frontend/layouts/layout/themes-customer/grey.css )
Rails.application.config.assets.precompile += %w( spree/manage/all.css )
Rails.application.config.assets.precompile += %w( spree/cust/all.css )

Rails.application.config.assets.precompile += %w( fonts.css )
Rails.application.config.assets.precompile << /\.(?:svg|eot|woff|ttf)$/

Rails.application.config.assets.precompile += %w( logo/spree_50.png )
Rails.application.config.assets.precompile += %w( noimage/small.png )
Rails.application.config.assets.precompile += %w( noimage/mini.png )
Rails.application.config.assets.precompile += %w( noimage/product.png )
Rails.application.config.assets.precompile += %w( noimage/large.png )
Rails.application.config.assets.precompile += %w( favicon.ico )
Rails.application.config.assets.precompile += %w( credit_cards/credit_card.gif )

Rails.application.config.assets.precompile += %w( ckeditor/*)

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )
