module TopologicalInventory
  module Scheduler
    class Worker
      def initialize(opts = {})
        messaging_client_opts = opts.select { |k, _| %i[host port].include?(k) }
        self.messaging_client_opts = default_messaging_opts.merge(messaging_client_opts)
      end

      def run
        # TODO
      end

      private

      attr_accessor :messaging_client_opts

      def messaging_client
        @messaging_client ||= ManageIQ::Messaging::Client.open(messaging_client_opts)
      end

      def default_messaging_opts
        {
          :encoding => 'json',
          :protocol => :Kafka
        }.merge(messaging_client_opts)
      end
    end
  end
end
