module Integrations
  class Action < BaseObject
    def result
      result = {}
      result[:message] = @data[:message]
      result[:backtrace] = @data[:backtrace]
      result[:status] = status
      result
    end

    def status
      return -1 if @data[:level] == 'error'
      return 10 if @data[:level] == 'done'
    end
  end
end
