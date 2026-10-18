# frozen_string_literal: true

RSpec.describe "Choosing a listing from the new topic chooser" do
  fab!(:seller) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:market) { Fabricate(:category, name: "Market") }
  fab!(:other_category) { Fabricate(:category, name: "General chat") }

  let(:listing_form) { PageObjects::Modals::KuuMarketListingForm.new }
  let(:category_page) { PageObjects::Pages::Category.new }
  let(:photo) { file_from_fixtures("logo.png", "images") }

  let(:chooser) { ".kuu-new-topic-choice" }
  let(:market_option) do
    "#{chooser} .kuu-new-topic-choice__option[data-type-id='kuu-market-listing']"
  end

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    sign_in(seller)
  end

  def post_from_chooser
    find(market_option).click
    expect(listing_form).to be_open

    listing_form.fill_in("item_name", "IKEA desk").fill_in("price", "3000")
    listing_form.upload_photo(photo)
    listing_form.submit

    expect(page).to have_css("#topic-title", text: "[For sale] IKEA desk · ¥3,000")
  end

  it "offers a listing on Latest, right after a regular topic, and posts it in the market" do
    visit("/latest")
    find("#create-topic").click

    expect(page).to have_css(market_option)
    options = all("#{chooser} .kuu-new-topic-choice__option")
    expect(options.first[:class]).to include("--topic")
    expect(options[1]["data-type-id"]).to eq("kuu-market-listing")

    post_from_chooser

    expect(DiscourseKuuMarket::Listing.last.topic.category).to eq(market)
  end

  it "offers a listing in another category and still posts it in the market" do
    category_page.visit(other_category)
    category_page.new_topic_button.click

    post_from_chooser

    expect(DiscourseKuuMarket::Listing.last.topic.category).to eq(market)
  end

  it "still opens the form straight away in the market" do
    category_page.visit(market)
    category_page.new_topic_button.click

    expect(listing_form).to be_open
    expect(page).to have_no_css(chooser)
  end

  it "leaves the listing out for users who cannot post in the market" do
    market.set_permissions(everyone: :readonly)
    market.save!

    visit("/latest")
    find("#create-topic").click

    # 没有别的类型时直接打开编辑器，否则弹出选择框；两种情况都不能有二手帖
    expect(page).to have_css("#{chooser}, #reply-control.open")
    expect(page).to have_no_css(market_option)
  end
end
