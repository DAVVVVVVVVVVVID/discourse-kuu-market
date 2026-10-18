# frozen_string_literal: true

# 已出、结束、过期的二手帖靠 core 的「隐藏话题」从别人的列表和搜索里去掉。
# 这里逐个核对技术方案 2.3 列出的地方，core 以后改了行为能第一时间发现
RSpec.describe "Who sees listings that are no longer in progress" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true, created_at: 1.month.ago) }
  fab!(:viewer) { Fabricate(:user, refresh_auto_groups: true, created_at: 1.month.ago) }
  fab!(:admin)
  fab!(:market) { Fabricate(:category, name: "Market") }
  fab!(:other_topic) { Fabricate(:topic_with_op, title: "Where to buy a bike near campus") }

  let(:selling) { listed_topic("IKEA desk") }
  let(:sold) { listed_topic("IKEA chair", status: "sold") }
  let(:expired) { listed_topic("IKEA lamp", status: "expired") }
  let(:hidden_ids) { [sold.id, expired.id] }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.default_locale = "zh_CN"
    SearchIndexer.enable
    UserActionManager.enable
    [selling, sold, expired]
  end

  def listed_topic(item_name, status: nil)
    photo = Fabricate(:image_upload, user: seller)
    result =
      DiscourseKuuMarket::Listing::Create.call(
        params: {
          kind: "sell",
          item_name:,
          price: 1000,
          location: "吉田本校区",
          trade_method: "pickup",
          upload_ids: [photo.id],
        },
        guardian: seller.guardian,
      )
    topic = result.new_post_result.post.topic
    listing = topic.kuu_market_listing

    if status == "expired"
      listing.status = "expired"
      DiscourseKuuMarket::Listing::Action::SyncTopic.call(listing:)
      listing.save!
    elsif status
      DiscourseKuuMarket::Listing::ChangeStatus.call(
        params: {
          topic_id: topic.id,
          status:,
        },
        guardian: seller.guardian,
      )
    end

    topic.reload
  end

  def topic_ids(path)
    get path
    expect(response.status).to eq(200)
    response.parsed_body["topic_list"]["topics"].map { it["id"] }
  end

  context "when someone else browses" do
    before { sign_in(viewer) }

    it "hides them from Latest" do
      ids = topic_ids("/latest.json")

      expect(ids).to include(selling.id)
      expect(ids).not_to include(*hidden_ids)
    end

    it "hides them from New" do
      viewer.user_option.update!(new_topic_duration_minutes: User::NewTopicDuration::ALWAYS)

      ids = topic_ids("/new.json")

      expect(ids).to include(selling.id)
      expect(ids).not_to include(*hidden_ids)
    end

    it "hides them from Unread" do
      [selling, sold].each do |topic|
        TopicUser.change(
          viewer.id,
          topic.id,
          last_read_post_number: 1,
          notification_level: TopicUser.notification_levels[:tracking],
        )
        Fabricate(:post, topic:)
      end

      ids = topic_ids("/unread.json")

      expect(ids).to include(selling.id)
      expect(ids).not_to include(sold.id)
    end

    it "hides them from Hot and Top" do
      [selling, sold, expired].each do |topic|
        TopicHotScore.create!(topic:, score: 1)
        TopTopic.create!(topic:, all_score: 1)
      end

      expect(topic_ids("/hot.json")).not_to include(*hidden_ids)
      expect(topic_ids("/top.json?period=all")).to include(selling.id)
      expect(topic_ids("/top.json?period=all")).not_to include(*hidden_ids)
    end

    it "hides them from the market category page" do
      ids = topic_ids("/c/#{market.slug}/#{market.id}.json")

      expect(ids).to include(selling.id)
      expect(ids).not_to include(*hidden_ids)
    end

    it "hides them from the featured topics of the categories page" do
      CategoryFeaturedTopic.feature_topics_for(market)

      expect(CategoryFeaturedTopic.where(category: market).pluck(:topic_id)).not_to include(
        *hidden_ids,
      )
    end

    it "hides them from suggested topics" do
      get "/t/#{other_topic.id}.json"

      suggested_ids = response.parsed_body["suggested_topics"].map { it["id"] }
      expect(suggested_ids).to include(selling.id)
      expect(suggested_ids).not_to include(*hidden_ids)
    end

    it "hides them from the seller's profile" do
      SiteSetting.hide_new_user_profiles = false

      expect(topic_ids("/topics/created-by/#{seller.username}")).to contain_exactly(selling.id)

      get "/user_actions.json", params: { username: seller.username, filter: UserAction::NEW_TOPIC }
      expect(response.parsed_body["user_actions"].map { it["topic_id"] }).to contain_exactly(
        selling.id,
      )
    end

    it "hides them from search" do
      get "/search.json", params: { q: "IKEA" }

      ids = response.parsed_body["topics"].map { it["id"] }
      expect(ids).to include(selling.id)
      expect(ids).not_to include(*hidden_ids)
    end

    it "still opens them by link" do
      get "/t/#{sold.id}.json"

      expect(response.status).to eq(200)
    end
  end

  context "when the seller browses" do
    before { sign_in(seller) }

    it "shows all their listings under their own Activity → Topics" do
      expect(topic_ids("/topics/created-by/#{seller.username}")).to include(selling.id, *hidden_ids)
    end

    it "keeps them out of the seller's Latest" do
      expect(topic_ids("/latest.json")).not_to include(*hidden_ids)
    end
  end

  context "when staff browses" do
    before { sign_in(admin) }

    it "shows them in every list" do
      expect(topic_ids("/latest.json")).to include(selling.id, *hidden_ids)
      expect(topic_ids("/c/#{market.slug}/#{market.id}.json")).to include(selling.id, *hidden_ids)
    end

    it "finds them in search with include:unlisted" do
      get "/search.json", params: { q: "IKEA include:unlisted" }

      expect(response.parsed_body["topics"].map { it["id"] }).to include(*hidden_ids)
    end
  end

  describe "the listing's kind and status on topic list items" do
    before { sign_in(admin) }

    it "is included for listings in the market" do
      get "/latest.json"

      items = response.parsed_body["topic_list"]["topics"].index_by { it["id"] }
      expect(items[selling.id]).to include(
        "kuu_market_kind" => "sell",
        "kuu_market_status" => "selling",
        "kuu_market_title_prefix" => "【出售】",
      )
      expect(items[sold.id]).to include("kuu_market_status" => "sold")
      expect(items[other_topic.id]).not_to have_key("kuu_market_kind")
    end

    it "is left out once a listing is moved out of the market" do
      selling.update!(category: Fabricate(:category))

      get "/latest.json"

      item = response.parsed_body["topic_list"]["topics"].find { it["id"] == selling.id }
      expect(item).not_to have_key("kuu_market_status")
    end

    it "does not query each listing separately" do
      get "/latest.json"
      expect(response.status).to eq(200)

      3.times { listed_topic("Shelf #{SecureRandom.hex(2)}") }

      queries = track_sql_queries { get "/latest.json" }
      expect(queries.count { it.include?("kuu_market_listings") }).to eq(1)
    end
  end
end
