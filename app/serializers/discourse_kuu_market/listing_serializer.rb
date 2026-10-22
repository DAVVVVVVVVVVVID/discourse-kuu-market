# frozen_string_literal: true

module DiscourseKuuMarket
  class ListingSerializer < ApplicationSerializer
    attributes :topic_id,
               :kind,
               :status,
               :item_name,
               :price,
               :free,
               :budget_min,
               :budget_max,
               :location,
               :area,
               :categories,
               :trade_method,
               :description,
               :upload_ids,
               :active_since,
               :next_bump_at
  end
end
