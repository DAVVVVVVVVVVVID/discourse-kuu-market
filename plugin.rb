# frozen_string_literal: true

# name: discourse-kuu-market
# about: 二手市场：用专门的表单发出售 / 求购帖，作者可以标记状态，成交和过期的帖子不再出现在别人的列表和搜索里
# version: 0.0.1
# authors: DAVVVVVVVVVVVID
# url: https://github.com/DAVVVVVVVVVVVID/discourse-kuu-market
# required_version: 2026.1.0

enabled_site_setting :kuu_market_enabled

register_asset "stylesheets/common/kuu-market.scss"

register_svg_icon "clock-rotate-left"
register_svg_icon "cart-shopping"
register_svg_icon "magnifying-glass"
register_svg_icon "hand"
register_svg_icon "arrow-right"

module ::DiscourseKuuMarket
  PLUGIN_NAME = "discourse-kuu-market"

  def self.market_category?(category_id)
    market_category_id = SiteSetting.kuu_market_category.to_i
    market_category_id > 0 && category_id.to_i == market_category_id
  end

  # 两个人之间的聊天私聊频道（没有就是 nil），前端「去私信」直接打开它
  def self.direct_message_channel_id(user, other_user)
    Chat::DirectMessage.for_user_ids([user.id, other_user.id])&.direct_message_channel&.id
  end
end

require_relative "lib/discourse_kuu_market/engine"

# ---- 和 discourse-kuu-buddy 共用，两边的这一段要保持一样（二手 Issue #19，2026-10-25）----
# 几个 KUU 插件都会把自己隐藏的帖子放回「个人主页 → 话题」。各插件只往 SOURCES 里登记自己要放出的帖子，
# 条件由 reveal 统一合成：所有来源合在一个 OR 里。各插件仍然各自注册 modifier（core 只在登记它的插件开着时
# 才执行 modifier，只注册一次的话那个插件一关，别的插件也失效）；两个都执行时只是重复加同一个条件，结果不变
module ::KuuProfileTopics
  # 名字 => lambda，返回要放出的 topic_id（select(:topic_id) 的 relation）；插件开关关着时返回空
  SOURCES = {} if !const_defined?(:SOURCES)

  if !respond_to?(:reveal)
    def self.reveal(topics, options)
      return topics if options[:filter] != :user_topics || options[:visible] != true
      return topics if SOURCES.empty?

      ids_sql = SOURCES.values.map { |source| "(#{source.call.to_sql})" }.join(" UNION ")
      topics.unscope(where: :visible).where("topics.visible OR topics.id IN (#{ids_sql})")
    end
  end
end
# ---- 共用部分结束 ----

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

  # 已出 / 已购买的帖子是隐藏话题，列表和搜索里都没有；但发帖人主页的「话题」里所有人都能看到
  # （Issue #5 规则 7），过期的不放出。和搭子插件共用 KuuProfileTopics，见文件开头（Issue #19）
  KuuProfileTopics::SOURCES[:market] = -> do
    listings = DiscourseKuuMarket::Listing
    (SiteSetting.kuu_market_enabled ? listings.deals_unlisted_by_plugin : listings.none).select(
      :topic_id,
    )
  end

  register_modifier(:topic_query_create_list_topics) do |topics, options, _topic_query|
    KuuProfileTopics.reveal(topics, options)
  end

  # 作者本人和管理员可以随时修改二手帖、切换状态，不受编辑时限限制；作者被禁言时不行
  add_to_class(:guardian, :can_manage_kuu_market_listing?) do |listing|
    topic = listing.topic
    return false if anonymous? || topic.nil? || topic.trashed? || !can_see?(topic)
    return true if is_staff?

    topic.user_id == user.id && !user.silenced?
  end

  # 在售 / 求购中的帖子，作者以外的登录用户可以举手（包括管理员）；已出、结束、过期的不行
  add_to_class(:guardian, :can_raise_kuu_market_hand?) do |listing|
    return false if anonymous? || user.silenced?
    return false if listing.topic_deleted? || !listing.in_market? || !listing.active?

    listing.topic.user_id != user.id && can_see?(listing.topic)
  end

  add_to_serializer(
    :topic_view,
    :kuu_market_listing,
    include_condition: -> { object.topic.kuu_market_listing_in_market.present? },
  ) do
    DiscourseKuuMarket::TopicListingSerializer.new(
      object.topic.kuu_market_listing_in_market,
      scope:,
      root: false,
    ).as_json
  end

  # 有新的人举手时，发帖人下次打开论坛弹窗提醒（Issue #5 第二期）。没有时是 nil
  add_to_serializer(:current_user, :kuu_market_hand_alerts) do
    DiscourseKuuMarket::RaisedHand.alerts_for(object)
  end

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

  # 帖子列表里二手帖显示成商品卡片用（Issue #1）。只给二手帖加，记录已经批量预加载
  add_to_serializer(
    :topic_list_item,
    :kuu_market_card,
    include_condition: -> { object.kuu_market_listing_in_market.present? },
  ) do
    listing = object.kuu_market_listing_in_market
    {
      item_name: listing.item_name,
      price: DiscourseKuuMarket::ListingRenderer.new(listing).card_price,
      free: listing.sell? && listing.free,
      has_photos: listing.upload_ids.any?,
      area: listing.area,
      categories: listing.categories,
    }
  end

  # 二手市场页按校区、商品分类筛选（Issue #11）：网址里的 kuu_area / kuu_category。
  # 不认识的值不筛选；上线前发的帖子没有这两项，筛选时不出现
  TopicQuery.add_custom_filter(:kuu_area) do |results, topic_query|
    area = topic_query.options[:kuu_area]
    if !SiteSetting.kuu_market_enabled || DiscourseKuuMarket::Listing::AREAS.exclude?(area)
      next results
    end

    results.where("topics.id IN (?)", DiscourseKuuMarket::Listing.where(area:).select(:topic_id))
  end

  TopicQuery.add_custom_filter(:kuu_category) do |results, topic_query|
    category = topic_query.options[:kuu_category]
    if !SiteSetting.kuu_market_enabled || DiscourseKuuMarket::Listing::CATEGORIES.exclude?(category)
      next results
    end

    results.where(
      "topics.id IN (?)",
      DiscourseKuuMarket::Listing.where("categories @> ARRAY[?]::varchar[]", category).select(
        :topic_id,
      ),
    )
  end

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

  on(:topic_category_changed) do |topic, _old_category|
    DiscourseKuuMarket::Listing::FollowCategoryChange.call(params: { topic_id: topic.id })
  end

  # 排在 core 的标题校验之后、valid? 得出结果之前；after_validation 太晚
  add_model_callback(:topic, :validate) do
    DiscourseKuuMarket::FormSubmission.forgive_title_errors(self)
    DiscourseKuuMarket::EditRules.check_topic(self)
  end

  add_model_callback(:post, :validate) { DiscourseKuuMarket::EditRules.check_post(self) }
end
