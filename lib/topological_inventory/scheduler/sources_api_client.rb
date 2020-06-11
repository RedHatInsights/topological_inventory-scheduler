require "sources-api-client"

module TopologicalInventory
  module Scheduler
    class SourcesApiClient
      include Logging

      ORCHESTRATOR_TENANT = 'system_orchestrator'.freeze

      def load_source_types
        api_client.list_source_types
      end

      private

      def identity(tenant_account = ORCHESTRATOR_TENANT)
        {'x-rh-identity' => Base64.strict_encode64({'identity' => {'account_number' => tenant_account, 'user' => {'is_org_admin' => true}}}.to_json)}
      end

      def api_client
        @api_client ||= begin
                          api_client = SourcesApiClient::ApiClient.new
                          api_client.default_headers.merge!(identity)
                          SourcesApiClient::DefaultApi.new(api_client)
                        end
      end
    end
  end
end