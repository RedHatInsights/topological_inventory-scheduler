require 'topological_inventory/scheduler/logging'
require 'active_support/core_ext/integer/time'

module TopologicalInventory
  module Scheduler
    class DatabaseTools
      include Logging

      REFRESH_STATES_TIME_THRESHOLD = 1.week.freeze

      def remove_old_records
        threshold = DateTime.now - REFRESH_STATES_TIME_THRESHOLD  

        logger.info("DatabaseTools: Deleting RefreshState records older than #{threshold} has started...")

        RefreshState.where('updated_at <= ?', threshold).delete_all

        logger.info("DatabaseTools: Deleting RefreshState records older than #{threshold} has finished...")
      rescue => e
        logger.error("#{e.message}\n#{e.backtrace.join("\n")}")
      end
    end
  end
end
