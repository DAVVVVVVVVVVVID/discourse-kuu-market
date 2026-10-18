# frozen_string_literal: true

RSpec.describe "Changing a listing's status on the topic page" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "Market") }
  fab!(:listing) do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    topic = Fabricate(:topic, user: seller, category: market)
    Fabricate(:post, topic:, user: seller)
    Fabricate(:kuu_market_listing, topic:, active_since: 10.days.ago, last_bumped_at: 10.days.ago)
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
  end

  def status_button(status)
    find(".kuu-market-panel__change[data-status='#{status}']")
  end

  it "lets the seller mark it as sold after confirming, then relist it" do
    sign_in(seller)
    topic_page.visit_topic(listing.topic)

    expect(page).to have_css(".kuu-market-panel__status.kuu-market-status-selling")
    expect(page).to have_css(".kuu-market-panel__expiry")

    status_button("sold").click
    dialog.click_yes

    expect(page).to have_css(".kuu-market-panel__status.kuu-market-status-sold")
    expect(listing.reload.status).to eq("sold")
    expect(listing.topic.reload).to have_attributes(closed: true, visible: false)

    status_button("selling").click

    expect(toasts).to have_success(I18n.t("js.kuu_market.panel.relisted_and_bumped"))
    expect(page).to have_css(".kuu-market-panel__status.kuu-market-status-selling")
    expect(listing.reload.status).to eq("selling")
  end

  it "keeps the listing as it was when the seller cancels" do
    sign_in(seller)
    topic_page.visit_topic(listing.topic)

    status_button("sold").click
    dialog.click_no

    expect(page).to have_css(".kuu-market-panel__status.kuu-market-status-selling")
    expect(listing.reload.status).to eq("selling")
  end

  it "tells the seller when the relisting was not bumped" do
    listing.update!(status: "sold", last_bumped_at: 1.day.ago)
    sign_in(seller)
    topic_page.visit_topic(listing.topic)

    status_button("selling").click

    expect(page).to have_css(".fk-d-default-toast", text: "It was not bumped this time")
    expect(listing.reload.status).to eq("selling")
  end

  it "offers both ways out of an expired listing" do
    listing.update!(status: "expired")
    sign_in(seller)
    topic_page.visit_topic(listing.topic)

    expect(page).to have_css(".kuu-market-panel__status.kuu-market-status-expired")
    expect(page).to have_css(".kuu-market-panel__change", count: 2)
  end

  it "shows only the status to other users" do
    sign_in(Fabricate(:user))
    topic_page.visit_topic(listing.topic)

    expect(page).to have_css(".kuu-market-panel__status.kuu-market-status-selling")
    expect(page).to have_no_css(".kuu-market-panel__change")
    expect(page).to have_no_css(".kuu-market-panel__expiry")
  end
end
