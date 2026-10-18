# frozen_string_literal: true

RSpec.describe "Posting and editing a listing" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "Market") }
  fab!(:photo) { file_from_fixtures("logo.png", "images") }

  let(:listing_form) { PageObjects::Modals::KuuMarketListingForm.new }
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    sign_in(seller)
  end

  def open_form
    category_page.visit(market)
    category_page.new_topic_button.click
    expect(listing_form).to be_open
  end

  it "opens the market form instead of the composer in the market" do
    open_form

    expect(composer).to be_closed
  end

  it "posts a listing for sale with a photo" do
    open_form
    listing_form.fill_in("item_name", "IKEA desk").fill_in("price", "3000")
    listing_form.fill_in("description", "Barely used, pick up this weekend")
    listing_form.upload_photo(photo)
    listing_form.submit

    expect(page).to have_css("#topic-title", text: "[For sale] IKEA desk · ¥3,000")
    expect(page).to have_css(".cooked img")
    expect(page).to have_css(".cooked", text: "Barely used, pick up this weekend")
    expect(DiscourseKuuMarket::Listing.last).to have_attributes(kind: "sell", price: 3000)
  end

  it "posts a wanted listing without a photo" do
    open_form
    listing_form.choose_kind("buy").fill_in("item_name", "Bicycle").fill_in("budget_max", "10000")
    listing_form.submit

    expect(page).to have_css("#topic-title", text: "[Wanted] Bicycle · up to ¥10,000")
  end

  it "points out what is missing" do
    open_form
    listing_form.submit

    expect(listing_form).to have_field_error("item_name")
    expect(listing_form).to have_field_error("price")
    expect(listing_form).to have_field_error("photos")
    expect(DiscourseKuuMarket::Listing.count).to eq(0)
  end

  it "asks for at least one end of the budget" do
    open_form
    listing_form.choose_kind("buy").fill_in("item_name", "Bicycle")
    listing_form.submit

    expect(listing_form).to have_field_error("budget_max")
  end

  it "lets the seller type another meeting place" do
    open_form
    listing_form.fill_in("item_name", "Rice cooker")
    listing_form.field("free").toggle
    listing_form.field("location").select(OTHER_LOCATION_VALUE)
    listing_form.fill_in("location_other", "Hyakumanben")
    listing_form.upload_photo(photo)
    listing_form.submit

    expect(page).to have_css("#topic-title", text: "[Free] Rice cooker")
    expect(DiscourseKuuMarket::Listing.last.location).to eq("Hyakumanben")
  end

  context "with a posted listing" do
    fab!(:listing) do
      SiteSetting.kuu_market_enabled = true
      SiteSetting.kuu_market_category = market.id
      upload = Fabricate(:image_upload, user: seller)
      DiscourseKuuMarket::Listing::Create.call(
        params: {
          kind: "sell",
          item_name: "IKEA desk",
          price: 3000,
          location: "吉田本校区",
          trade_method: "pickup",
          upload_ids: [upload.id],
        },
        guardian: seller.guardian,
      )
      DiscourseKuuMarket::Listing.last
    end

    it "edits it with the same form instead of the composer" do
      topic_page.visit_topic(listing.topic)

      expect(page).to have_no_css("#post_1 .post-controls .edit")

      find(".kuu-market-panel__edit").click
      expect(listing_form).to be_open
      expect(listing_form).to have_no_css(".form-kit__field[data-name='kind']")
      expect(listing_form).to have_photos(1)

      listing_form.fill_in("price", "2000")
      listing_form.submit

      expect(page).to have_css("#topic-title", text: "[For sale] IKEA desk · ¥2,000")
      expect(listing.reload.price).to eq(2000)
    end

    it "shows no edit button to other users" do
      sign_in(Fabricate(:user))
      topic_page.visit_topic(listing.topic)

      expect(page).to have_css("#post_1")
      expect(page).to have_no_css(".kuu-market-panel__edit")
    end
  end

  OTHER_LOCATION_VALUE = "__other__"
end
