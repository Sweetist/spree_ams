if Rails.env ==  "production" || Rails.env == "staging" || Rails.env ==  "production_on_local" || Rails.env == "staging_on_local"
	attachment_config = {

	  s3_credentials: {
	    access_key_id:     ENV['S3_ACCESS_KEY'],
	    secret_access_key: ENV['S3_SECRET'],
	    bucket:            ENV['S3_BUCKET']
	  },

	  storage:        :s3,
	  s3_headers:     { "Cache-Control" => "max-age=31557600" },
	  s3_protocol:    "https",
	  bucket:         ENV['S3_BUCKET_NAME'],
	  url:            ":s3_domain_url",

	  styles: {
	     mini:     "48x48>",
 	     small:    "100x100>",
 	     product:  "240x240>",
 	     large:    "600x600>"
	  },

	  path:           "/:class/:id/:style/:basename.:extension",
	  default_url:    "/:class/:id/:style/:basename.:extension",
	  default_style:  "product"
	}

	attachment_config.each do |key, value|
 		Spree::Image.attachment_definitions[:attachment][key.to_sym] = value
	end
end
