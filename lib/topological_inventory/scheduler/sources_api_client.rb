require 'sources-api-client'

module TopologicalInventory
  module Scheduler
    class SourcesApiClient < ::SourcesApiClient::ApiClient
      STATUS_AVAILABLE, STATUS_UNAVAILABLE, STATUS_UNKNOWN = %w[available unavailable unknown].freeze

      def initialize
        super(::SourcesApiClient::Configuration.default)
        self.api = ::SourcesApiClient::DefaultApi.new(self)

        @sources_status = {}
      end

      def source_available?(source_id, identity)
        @sources_status[source_id] = get_source_status(source_id, identity) if @sources_status[source_id].nil?

        @sources_status[source_id] == STATUS_AVAILABLE
      end

      private

      attr_accessor :api

      def get_source_status(source_id, identity)
        return STATUS_UNKNOWN if identity.try(:[], 'x-rh-identity').nil?

        source = fetch_source(source_id, identity)
        source&.availability_status || STATUS_UNAVAILABLE
      end

      # TODO: Optimize, group sources by tenant
      def fetch_source(source_id, identity)
        api.show_source(source_id.to_s, :header_params => identity)
      end
    end
  end
end
