module Spree
  class Version < PaperTrail::Version
    self.table_name = :versions

    def event_array
      [
        event.to_s,
        controller.to_s,
        action.to_s,
        commit.to_s
      ]
    end

    def display_event_array
      event_array.join("\n")
    end

    def html_event_array
      event_array.join("<br>").html_safe
    end
  end
end
