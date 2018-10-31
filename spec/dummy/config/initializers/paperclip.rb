Paperclip.options[:content_type_mappings] = {
  csv: ['application/vnd.ms-excel', 'text/csv', 'text/plain', 'text/comma-separated-values']
}
module Paperclip
  class MediaTypeSpoofDetector
    def spoofed?
      if has_name? && media_type_mismatch? && mapping_override_mismatch?
       Paperclip.log("Content Type Spoof: Filename #{File.basename(@name)} (#{supplied_content_type} from Headers, #{content_types_from_name.map(&:to_s)} from Extension), content type discovered from file command: #{calculated_content_type}. See documentation to allow this combination.")
       true
      else
       false
      end
    end
    def media_type_mismatch?
      extension_type_mismatch? || calculated_type_mismatch?
    end

    def extension_type_mismatch?
      supplied_media_type.present? &&
        has_extension? &&
        !media_types_from_name.include?(supplied_media_type)
    end

    def calculated_type_mismatch?
      supplied_media_type.present? &&
        !calculated_content_type.include?(supplied_media_type)
    end

    def mapping_override_mismatch?
      !Array(mapped_content_type).include?(calculated_content_type)
    end

  end
end
