# frozen_string_literal: true

RSpec.describe "Editing a listing with the regular composer" do
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:market, :category)
  fab!(:listing) do
    topic = Fabricate(:topic, user: author, category: market)
    Fabricate(:post, topic:, user: author)
    Fabricate(:kuu_market_listing, topic:)
  end

  let(:topic) { listing.topic }
  let(:first_post) { topic.first_post }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
  end

  it "stops the author from editing the first post" do
    sign_in(author)

    put "/posts/#{first_post.id}.json",
        params: {
          post: {
            raw: "Changed by hand, not by the form",
          },
        }

    expect(response.status).to eq(422)
    expect(response.parsed_body["errors"]).to include(
      I18n.t("kuu_market.errors.edit_with_market_form"),
    )
    expect(first_post.reload.raw).not_to eq("Changed by hand, not by the form")
  end

  it "stops the author from renaming the topic" do
    sign_in(author)

    put "/t/#{topic.slug}/#{topic.id}.json", params: { title: "A brand new title for my desk" }

    expect(response.status).to eq(422)
    expect(topic.reload.title).not_to eq("A brand new title for my desk")
  end

  it "lets staff edit the first post by hand" do
    sign_in(admin)

    put "/posts/#{first_post.id}.json", params: { post: { raw: "Phone number removed by staff" } }

    expect(response.status).to eq(200)
    expect(first_post.reload.raw).to eq("Phone number removed by staff")
  end

  it "lets the author edit their replies" do
    reply = Fabricate(:post, topic:, user: author)
    sign_in(author)

    put "/posts/#{reply.id}.json", params: { post: { raw: "Still available this weekend" } }

    expect(response.status).to eq(200)
  end

  it "does not touch topics without a listing" do
    rules = Fabricate(:topic, user: author, category: market)
    rules_post = Fabricate(:post, topic: rules, user: author)
    sign_in(author)

    put "/posts/#{rules_post.id}.json", params: { post: { raw: "Updated market rules text" } }

    expect(response.status).to eq(200)
  end

  it "does nothing while the plugin is disabled" do
    SiteSetting.kuu_market_enabled = false
    sign_in(author)

    put "/posts/#{first_post.id}.json",
        params: {
          post: {
            raw: "Changed by hand, not by the form",
          },
        }

    expect(response.status).to eq(200)
  end
end
