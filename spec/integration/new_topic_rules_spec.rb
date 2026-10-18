# frozen_string_literal: true

RSpec.describe "Posting in the market with the regular composer" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:market, :category)
  fab!(:other_category, :category)

  let(:topic_params) do
    {
      title: "Selling an IKEA desk in good condition",
      raw: "Anyone interested? You can come and see it this weekend.",
      category: market.id,
    }
  end

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
  end

  it "rejects a new topic in the market" do
    sign_in(user)

    expect { post "/posts.json", params: topic_params }.not_to change { Topic.count }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to contain_exactly(
      I18n.t("kuu_market.errors.use_market_form"),
    )
  end

  it "ignores a listing parameter smuggled into the request" do
    sign_in(user)

    post "/posts.json",
         params: topic_params.merge(kuu_market_listing: { kind: "sell", item_name: "书桌" })

    expect(response.status).to eq(422)
  end

  it "lets staff post a regular topic in the market" do
    sign_in(admin)

    post "/posts.json", params: topic_params

    expect(response.status).to eq(200)
    expect(Topic.last.kuu_market_listing).to be_nil
  end

  it "keeps replies in the market working" do
    rules_topic = Fabricate(:topic_with_op, category: market)
    sign_in(user)

    post "/posts.json",
         params: {
           topic_id: rules_topic.id,
           raw: "Is Saturday afternoon still possible for you?",
         }

    expect(response.status).to eq(200)
  end

  it "does not touch other categories" do
    sign_in(user)

    post "/posts.json", params: topic_params.merge(category: other_category.id)

    expect(response.status).to eq(200)
  end

  it "does nothing while the plugin is disabled" do
    SiteSetting.kuu_market_enabled = false
    sign_in(user)

    post "/posts.json", params: topic_params

    expect(response.status).to eq(200)
  end
end
