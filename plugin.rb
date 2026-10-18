# frozen_string_literal: true

# name: discourse-kuu-market
# about: 二手市场：用专门的表单发出售 / 求购帖，作者可以标记状态，成交和过期的帖子不再出现在别人的列表和搜索里
# version: 0.0.1
# authors: DAVVVVVVVVVVVID
# url: https://github.com/DAVVVVVVVVVVVID/discourse-kuu-market
# required_version: 2026.1.0

enabled_site_setting :kuu_market_enabled

module ::DiscourseKuuMarket
  PLUGIN_NAME = "discourse-kuu-market"

  def self.market_category?(category_id)
    market_category_id = SiteSetting.kuu_market_category.to_i
    market_category_id > 0 && category_id.to_i == market_category_id
  end
end

require_relative "lib/discourse_kuu_market/engine"

after_initialize do
  reloadable_patch do
    Topic.has_one :kuu_market_listing,
                  class_name: "DiscourseKuuMarket::Listing",
                  dependent: :destroy,
                  autosave: true
  end

  # 移出二手市场的帖子不再受插件管理：没有类型和状态
  add_to_class(:topic, :kuu_market_listing_in_market) do
    kuu_market_listing if DiscourseKuuMarket.market_category?(category_id)
  end

  register_topic_preloader_associations(:kuu_market_listing) { SiteSetting.kuu_market_enabled }

  # 列表卡片的书签样式由 KUU 自定义组件按这两个值加的类名来写
  add_to_serializer(
    :topic_list_item,
    :kuu_market_kind,
    include_condition: -> { object.kuu_market_listing_in_market.present? },
  ) { object.kuu_market_listing_in_market.kind }

  add_to_serializer(
    :topic_list_item,
    :kuu_market_status,
    include_condition: -> { object.kuu_market_listing_in_market.present? },
  ) { object.kuu_market_listing_in_market.status }

  NewPostManager.add_handler(100) { |manager| DiscourseKuuMarket::NewTopicRules.check(manager) }

  # 需要审核的帖子，批准时由 core 按审核记录里存的参数建帖
  NewPostManager.add_plugin_payload_attribute(DiscourseKuuMarket::NewTopicRules::LISTING_ARG)

  # 发帖和审核通过建帖都会触发，二手帖记录和话题在同一个事务里保存
  on(:before_create_topic) do |topic, creator|
    attributes = creator.opts[DiscourseKuuMarket::NewTopicRules::LISTING_ARG]
    if attributes.present? && DiscourseKuuMarket.market_category?(topic.category_id)
      topic.kuu_market_listing = DiscourseKuuMarket::Listing.open(attributes)
    end
  end

  # 排在 core 的标题校验之后、valid? 得出结果之前；after_validation 太晚
  add_model_callback(:topic, :validate) do
    DiscourseKuuMarket::FormSubmission.forgive_title_errors(self)
    DiscourseKuuMarket::EditRules.check_topic(self)
  end

  add_model_callback(:post, :validate) { DiscourseKuuMarket::EditRules.check_post(self) }
end
