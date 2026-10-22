# frozen_string_literal: true

RSpec.describe "My listings page" do
  fab!(:seller) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:buyer) { Fabricate(:user, trust_level: TrustLevel[0], refresh_auto_groups: true) }
  fab!(:stranger) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "Market") }

  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:listing_form) { PageObjects::Modals::KuuMarketListingForm.new }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.chat_enabled = true
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_0]
  end

  def listed(fabricator = :kuu_market_listing, **attributes)
    topic = Fabricate(:topic, user: seller, category: market)
    Fabricate(:post, topic:, user: seller)
    Fabricate(fabricator, topic:, **attributes)
  end

  def item(listing)
    ".kuu-market-my-listings__item[data-topic-id='#{listing.topic_id}']"
  end

  def tab(key)
    find(".kuu-market-my-listings__tab[data-tab='#{key}']")
  end

  def visit_my_listings(user = seller)
    visit("/u/#{user.username}/market")
  end

  context "with listings in every state" do
    let!(:desk) { listed(item_name: "Desk") }
    let!(:chair) { listed(item_name: "Chair", status: "sold") }
    let!(:bike) do
      listed(
        :kuu_market_buy_listing,
        item_name: "Bike",
        status: "expired",
        active_since: 40.days.ago,
      )
    end

    before do
      # 卖家已经在举手提醒里看过，不然打开页面会先弹提醒
      desk.raised_hands.create!(user: buyer, alerted_at: 1.hour.ago)
      sign_in(seller)
    end

    it "groups them and switches between the groups" do
      visit_my_listings

      expect(tab("active")).to have_css(".kuu-market-my-listings__count", text: "1")
      expect(tab("dealt")).to have_css(".kuu-market-my-listings__count", text: "1")
      expect(tab("expired")).to have_css(".kuu-market-my-listings__count", text: "1")
      expect(page).to have_css(item(desk), text: "Desk")
      expect(page).to have_css("#{item(desk)} .kuu-market-my-listings__hands")
      expect(page).to have_no_css(item(chair))

      tab("dealt").click
      expect(page).to have_css(item(chair), text: "Chair")
      expect(page).to have_no_css(item(desk))

      tab("expired").click
      expect(page).to have_css(item(bike), text: "Bike")
    end

    it "marks a listing as sold, picking the buyer like on the topic page" do
      visit_my_listings

      find("#{item(desk)} .kuu-market-panel__change[data-status='sold']").click
      find(".kuu-market-deal-form input[type='radio'][value='#{buyer.id}']").click
      find(".kuu-market-deal-form__confirm").click

      expect(tab("dealt")).to have_css(".kuu-market-my-listings__count", text: "2")
      expect(desk.reload).to have_attributes(status: "sold", deal_user: buyer)
    end

    it "relists an expired listing" do
      visit_my_listings
      tab("expired").click

      find("#{item(bike)} .kuu-market-panel__change[data-status='buying']").click

      expect(tab("active")).to have_css(".kuu-market-my-listings__count", text: "2")
      expect(bike.reload.status).to eq("buying")
    end

    it "edits a listing with the same form" do
      visit_my_listings

      find("#{item(desk)} .kuu-market-panel__edit").click
      expect(listing_form).to be_open
      listing_form.fill_in("item_name", "Standing desk")
      listing_form.submit

      expect(page).to have_css(item(desk), text: "Standing desk")
      expect(desk.reload.item_name).to eq("Standing desk")
    end

    it "opens the topic" do
      visit_my_listings

      find("#{item(desk)} .kuu-market-my-listings__open").click

      expect(page).to have_current_path(%r{/t/[^/]+/#{desk.topic_id}})
    end
  end

  it "is reachable from the profile tab of the user menu" do
    listed(item_name: "Desk")
    sign_in(seller)
    visit("/latest")

    find("#toggle-current-user").click
    find("#user-menu-button-profile").click
    find(".kuu-market-my-listings-link a").click

    expect(page).to have_current_path("/u/#{seller.username_lower}/market")
    expect(page).to have_css(".kuu-market-my-listings__item")
  end

  it "is not available to other people" do
    listed(item_name: "Desk")
    sign_in(stranger)

    visit_my_listings

    expect(page).to have_css(".page-not-found")
    expect(page).to have_no_css(".kuu-market-my-listings")
  end

  it "invites people without listings to post one" do
    sign_in(buyer)

    visit_my_listings(buyer)

    expect(page).to have_css(".empty-state__title", text: I18n.t("js.kuu_market.my_listings.empty"))
    find(".empty-state__cta .btn-primary").click
    expect(listing_form).to be_open
  end
end
