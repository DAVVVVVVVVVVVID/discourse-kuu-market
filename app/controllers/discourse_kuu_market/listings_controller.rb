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
        on_failed_policy(:photos_available_to_user) { raise Discourse::InvalidAccess }
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

    def update
      Listing::Update.call(service_params) do
        on_success { head :no_content }
        on_model_not_found(:listing) { raise Discourse::NotFound }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_failed_policy(:listing_in_market) { raise Discourse::NotFound }
        on_failed_policy(:can_edit_listing) { raise Discourse::InvalidAccess }
        on_failed_policy(:kind_unchanged) do
          render(
            json: failed_json.merge(errors: [I18n.t("kuu_market.errors.kind_unchanged")]),
            status: :unprocessable_content,
          )
        end
        on_failed_policy(:photos_available_to_editor) { raise Discourse::InvalidAccess }
        on_model_errors(:revised_listing) do |listing|
          render(
            json: failed_json.merge(errors: listing.errors.full_messages),
            status: :unprocessable_content,
          )
        end
        on_failed_step(:revise_first_post) do |step|
          render(json: failed_json.merge(errors: [step.error]), status: :unprocessable_content)
        end
      end
    end

    def update_status
      Listing::ChangeStatus.call(service_params) do
        on_success do |listing:|
          render json: {
                   listing: ListingSerializer.new(listing, root: false).as_json,
                   bumped: listing.saved_change_to_last_bumped_at?,
                 }
        end
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:listing) { raise Discourse::NotFound }
        on_failed_policy(:listing_in_market) { raise Discourse::NotFound }
        on_failed_policy(:can_change_status) { raise Discourse::InvalidAccess }
        on_failed_policy(:status_reachable) do
          render(
            json: failed_json.merge(errors: [I18n.t("kuu_market.errors.status_unreachable")]),
            status: :unprocessable_content,
          )
        end
        on_failed_policy(:deal_user_in_queue) do
          render(
            json: failed_json.merge(errors: [I18n.t("kuu_market.errors.deal_user_not_in_queue")]),
            status: :unprocessable_content,
          )
        end
      end
    end

    def raise_hand
      Listing::RaiseHand.call(service_params) do
        on_success { |delivery:, listing:| render_hand_result(delivery, listing) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:listing) { raise Discourse::NotFound }
        on_failed_policy(:can_raise_hand) { raise Discourse::InvalidAccess }
        on_failed_policy(:hand_not_raised) do
          render(
            json: failed_json.merge(errors: [I18n.t("kuu_market.errors.hand_already_raised")]),
            status: :unprocessable_content,
          )
        end
        on_failed_policy(:within_daily_limit) { |policy| render_too_many_hand_actions(policy) }
      end
    end

    def cancel_hand
      Listing::CancelHand.call(service_params) do
        on_success { |delivery:, listing:| render_hand_result(delivery, listing) }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
        on_model_not_found(:listing) { raise Discourse::NotFound }
        on_failed_policy(:listing_open) { raise Discourse::InvalidAccess }
        on_model_not_found(:hand) { raise Discourse::NotFound }
        on_failed_policy(:within_daily_limit) { |policy| render_too_many_hand_actions(policy) }
      end
    end

    private

    def render_hand_result(delivery, listing)
      render json: {
               delivery:,
               listing: TopicListingSerializer.new(listing, scope: guardian, root: false).as_json,
             }
    end

    def render_too_many_hand_actions(policy)
      render(json: failed_json.merge(errors: [policy.reason]), status: :too_many_requests)
    end
  end
end
