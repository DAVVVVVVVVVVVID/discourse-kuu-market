# frozen_string_literal: true

RSpec.describe "Moving listings in and out of the market" do
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:market, :category)
  fab!(:other_category, :category)
  fab!(:topic) do
    Fabricate(:topic, user: author, category: market, title: "IKEA desk in good condition")
  end
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }
  fab!(:listing) { Fabricate(:kuu_market_listing, topic:) }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    DiscourseKuuMarket::Listing::ChangeStatus.call(
      params: {
        topic_id: topic.id,
        status: "sold",
      },
      guardian: author.guardian,
    )
    sign_in(admin)
  end

  def move_to(category)
    put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: category.id }
    expect(response.status).to eq(200)
  end

  it "reopens and shows a sold listing moved out of the market" do
    move_to(other_category)

    expect(topic.reload).to have_attributes(closed: false, visible: true)
    expect(listing.reload).to have_attributes(
      status: "sold",
      closed_by_plugin: false,
      unlisted_by_plugin: false,
    )
  end

  it "applies the status again when it is moved back" do
    move_to(other_category)
    move_to(market)

    expect(topic.reload).to have_attributes(closed: true, visible: false)
  end

  it "gives no status to an ordinary topic moved into the market" do
    ordinary = Fabricate(:topic_with_op, category: other_category)

    put "/t/#{ordinary.slug}/#{ordinary.id}.json", params: { category_id: market.id }

    expect(response.status).to eq(200)
    expect(ordinary.reload.kuu_market_listing).to be_nil
    expect(ordinary).to have_attributes(closed: false, visible: true)
  end
end
