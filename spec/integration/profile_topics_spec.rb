# frozen_string_literal: true

# 搭子插件也把自己隐藏的帖子（已结束）放回个人主页，两个插件共用 KuuProfileTopics（Issue #19）。
# CI 里只装了本插件，这里用一个假插件模拟搭子：登记一个来源，并像搭子一样注册自己的 modifier
RSpec.describe "Hidden topics revealed on profiles by several KUU plugins" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true, created_at: 1.month.ago) }
  fab!(:viewer) { Fabricate(:user, refresh_auto_groups: true, created_at: 1.month.ago) }
  fab!(:market, :category)
  fab!(:other_category, :category)

  # 「搭子」那边插件隐藏的帖子，和一个管理员隐藏的帖子
  fab!(:ended_activity) do
    Fabricate(:topic_with_op, user: seller, category: other_category, visible: false)
  end
  fab!(:unlisted_by_staff) do
    Fabricate(:topic_with_op, user: seller, category: other_category, visible: false)
  end

  let(:buddy_plugin) { Plugin::Instance.new }
  let(:buddy_modifier) do
    ->(topics, options, _topic_query) { KuuProfileTopics.reveal(topics, options) }
  end

  let!(:selling) { listed }
  let!(:sold) { listed(status: "sold") }
  let!(:expired) { listed(status: "expired") }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.hide_new_user_profiles = false

    KuuProfileTopics::SOURCES[:buddy] = -> { Topic.where(id: ended_activity.id).select(:id) }
    DiscoursePluginRegistry.register_modifier(
      buddy_plugin,
      :topic_query_create_list_topics,
      &buddy_modifier
    )
    sign_in(viewer)
  end

  after { uninstall_buddy }

  def uninstall_buddy
    KuuProfileTopics::SOURCES.delete(:buddy)
    return if @buddy_uninstalled

    DiscoursePluginRegistry.unregister_modifier(
      buddy_plugin,
      :topic_query_create_list_topics,
      &buddy_modifier
    )
    @buddy_uninstalled = true
  end

  def listed(status: nil)
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    topic = Fabricate(:topic_with_op, user: seller, category: market)
    listing = Fabricate(:kuu_market_listing, topic:)
    if status
      listing.status = status
      DiscourseKuuMarket::Listing::Action::SyncTopic.call(listing:)
      listing.save!
    end
    topic.reload
  end

  def profile_topic_ids
    get "/topics/created-by/#{seller.username}.json"
    expect(response.status).to eq(200)
    response.parsed_body["topic_list"]["topics"].map { it["id"] }
  end

  it "shows both plugins' revealed topics, but not expired or staff-unlisted ones" do
    expect(profile_topic_ids).to contain_exactly(selling.id, sold.id, ended_activity.id)
  end

  it "keeps the other plugin working when this one is turned off" do
    SiteSetting.kuu_market_enabled = false

    expect(profile_topic_ids).to contain_exactly(selling.id, ended_activity.id)
  end

  it "keeps this plugin working when the other one has nothing to reveal" do
    KuuProfileTopics::SOURCES[:buddy] = -> { Topic.none.select(:id) }

    expect(profile_topic_ids).to contain_exactly(selling.id, sold.id)
  end

  it "keeps this plugin working when the other one is not installed" do
    uninstall_buddy

    expect(profile_topic_ids).to contain_exactly(selling.id, sold.id)
  end

  it "leaves other topic lists alone" do
    get "/latest.json"

    ids = response.parsed_body["topic_list"]["topics"].map { it["id"] }
    expect(ids).to include(selling.id)
    expect(ids).not_to include(sold.id, ended_activity.id)
  end
end
