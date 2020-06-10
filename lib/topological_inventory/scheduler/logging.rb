require "manageiq/loggers"

module TopologicalInventory
  module Scheduler
    class << self
      attr_writer :logger
    end

    def self.logger
      @logger ||= ManageIQ::Loggers::CloudWatch.new
    end

    module Logging
      def logger
        TopologicalInventory::Scheduler.logger
      end
    end
  end
end
