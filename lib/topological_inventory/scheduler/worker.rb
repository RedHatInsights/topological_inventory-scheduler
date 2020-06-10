require "topological_inventory/scheduler/logging"
require "manageiq-messaging"

module TopologicalInventory
  module Scheduler
    class Worker
      include Logging

      REFRESH_QUEUE_NAME = "platform.topological-inventory.collector-ansible-tower".freeze

      def initialize(opts = {})
        messaging_client_opts = opts.select { |k, _| %i[host port].include?(k) }
        self.messaging_client_opts = default_messaging_opts.merge(messaging_client_opts)
      end

      # TODO: schedule also full refreshes
      def run
        # loop do
          tasks = load_running_tasks

          # TODO: refresh only for available sources
          invoke_targeted_refresh(tasks)

          # sleep(10)
        # end
      end

      private

      attr_accessor :messaging_client_opts

      def invoke_targeted_refresh(tasks)
        payload = {}

        tasks.each do |task|
          # grouping requests by Source
          # - tasks are ordered by source_id
          if payload[:source_id].present? && payload[:source_id] != task.source_id
            send_payload(payload)
            payload = {}
          end

          payload[:source_id] = task.source_id.to_s
          payload[:source_uid] = task.source_uid.to_s

          logger.info("Publishing ServiceInstance:SourceRef: #{task.target_source_ref}, Task: #{task.id}")
          payload[:params] ||= []
          payload[:params] << {
            :request_context => task.forwardable_headers,
            :source_ref      => task.target_source_ref,
            :task_id         => task.id
          }
        end

        # sending remaining data
        send_payload(payload) if payload[:params].present?
      end

      def load_running_tasks
        Task.where(:state => 'running', :target_type => 'ServiceInstance')
          .joins(:source)
          .select('tasks.id, tasks.source_id, tasks.target_source_ref, tasks.forwardable_headers, sources.uid as source_uid')
          .order('source_id')
      end

      def send_payload(payload)
        messaging_client.publish_topic(
          :service => REFRESH_QUEUE_NAME,
          :event   => "ServiceInstance.refresh",
          :payload => payload.to_json
        )
      end

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
