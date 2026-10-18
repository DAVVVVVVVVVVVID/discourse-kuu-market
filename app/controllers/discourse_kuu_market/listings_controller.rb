# frozen_string_literal: true

module DiscourseKuuMarket
  class ListingsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def create
      Listing::Create.call(service_params) do
        on_success do |new_post_result:|
          render json: serialize_data(new_post_result, NewPostResultSerializer, root: false)
        end
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:category) { raise Discourse::NotFound }
        on_failed_policy(:can_create_topic_in_category) { raise Discourse::InvalidAccess }
        on_failed_policy(:photos_uploaded_by_user) { raise Discourse::InvalidAccess }
        on_model_errors(:listing) do |listing|
          render(
            json: failed_json.merge(errors: listing.errors.full_messages),
            status: :unprocessable_content,
          )
        end
        on_exceptions(RateLimiter::LimitExceeded) { |exception| raise exception }
        on_failed_step(:publish_listing) do |step|
          render(json: failed_json.merge(errors: [step.error]), status: :unprocessable_content)
        end
      end
    end
  end
end
