require "topological_inventory/scheduler/logging"
require "manageiq-messaging"

module TopologicalInventory
  module Scheduler
    class Worker
      include Logging

      JOB_REFRESH_QUEUE_NAME = "platform.topological-inventory.collector-ansible-tower".freeze

      def initialize(opts = {})
        messaging_client_opts = opts.select { |k, _| %i[host port].include?(k) }
        self.messaging_client_opts = default_messaging_opts.merge(messaging_client_opts)
      end

      # TODO: schedule also full refreshes
      def run
        loop do
          tasks = load_running_tasks

          # TODO: refresh only for available sources
          invoke_targeted_refresh(tasks)

          sleep(10)
        end
      end

      private

      def invoke_targeted_refresh(tasks)
        payload = []

        tasks.each do |task|
          logger.info("Publishing ServiceInstance:SourceRef: #{task.target_source_ref}, Task: #{task.id}")
          payload <<
            {
              :request_context => task.forwardable_headers,
              :source_id       => task.source_id.to_s,
              :source_uid      => task.source_uid.to_s,
              :source_ref      => task.target_source_ref
            }
        end

        messaging_client.publish_topic(
          :service => JOB_REFRESH_QUEUE_NAME,
          :event   => "ServiceInstance.refresh",
          :payload => payload.to_json
        )
      end

      def load_running_tasks
        Task.where(:state => 'running', :target_type => 'ServiceInstance')
          .joins(:source).select('tasks.*, sources.uid as source_uid')
      end

      attr_accessor :messaging_client_opts

      def messaging_client
        @messaging_client ||= ManageIQ::Messaging::Client.open(messaging_client_opts)
      end

      def default_messaging_opts
        {
          :encoding => 'json',
          :protocol => :Kafka
        }
      end
    end
  end
end
