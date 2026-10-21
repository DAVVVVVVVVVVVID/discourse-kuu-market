# frozen_string_literal: true

module DiscourseKuuMarket
  class HandAlertsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    def dismiss
      RaisedHand::DismissAlerts.call(service_params) do
        on_success { head :no_content }
        on_failed_contract do |contract|
          render(
            json: failed_json.merge(errors: contract.errors.full_messages),
            status: :bad_request,
          )
        end
      end
    end
  end
end
