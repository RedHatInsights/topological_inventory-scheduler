FactoryBot.define do
  factory :task do
    forwardable_headers { {'x-rh-insights-request-id' => rand(1000).to_s} }
    source { association(:source) }
    state { 'running' }
    status { 'ok' }

    factory :task_svc_offering do
      initialize_with do
        Task.where(:name => name)
          .first_or_create(:forwardable_headers => forwardable_headers,
                           :state               => state,
                           :status              => status,
                           :source              => service_offering.source,
                           :target_type         => target_type,
                           :target_source_ref   => service_offering.source_ref,
                           :tenant              => source.tenant)
      end

      name { 'ServiceOffering#order' }
      target_type { 'ServiceOffering' }
    end

    factory :task_svc_instance do
      initialize_with do
        Task.where(:name => name)
            .first_or_create(:state             => state,
                             :status            => status,
                             :source            => service_instance.source,
                             :target_type       => target_type,
                             :target_source_ref => service_instance.source_ref,
                             :tenant            => source.tenant)
      end

      name { 'ServiceInstance#refresh' }
      target_type { 'ServiceInstance' }
    end
  end
end