# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::Listing::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_inclusion_of(:kind).in_array(%w[sell buy]) }
    it { is_expected.to validate_inclusion_of(:area).in_array(%w[yoshida uji katsura other]) }
    it { is_expected.not_to allow_value(nil).for(:area) }
    it { is_expected.not_to allow_value([]).for(:categories) }
    it { is_expected.to allow_value(%w[electronics study other]).for(:categories) }
    it { is_expected.not_to allow_value(%w[electronics study other clothing]).for(:categories) }
    it { is_expected.not_to allow_value(%w[electronics electronics]).for(:categories) }
    it { is_expected.not_to allow_value(%w[food]).for(:categories) }

    describe "#listing_attributes" do
      subject(:listing_attributes) { contract.listing_attributes }

      let(:contract) { described_class.new(**attributes) }

      context "with a sell listing" do
        let(:attributes) do
          {
            kind: "sell",
            item_name: "  宜家书桌  ",
            price: 3000,
            budget_min: 100,
            budget_max: 200,
            location: " 吉田本校区 ",
            area: "yoshida",
            categories: ["furniture_appliances"],
            trade_method: "pickup",
            description: "  九成新  ",
            upload_ids: [1],
          }
        end

        it "keeps the sell fields with stripped strings and drops the budget" do
          expect(listing_attributes).to eq(
            kind: "sell",
            item_name: "宜家书桌",
            location: "吉田本校区",
            area: "yoshida",
            categories: ["furniture_appliances"],
            description: "九成新",
            upload_ids: [1],
            price: 3000,
            free: false,
            trade_method: "pickup",
          )
        end
      end

      context "with a free sell listing" do
        let(:attributes) { { kind: "sell", price: 3000, free: true } }

        it "drops the price" do
          expect(listing_attributes).to include(price: nil, free: true)
        end
      end

      context "with a buy listing" do
        let(:attributes) do
          {
            kind: "buy",
            item_name: "自行车",
            price: 3000,
            free: true,
            budget_min: 5000,
            budget_max: 10_000,
            location: "桂校区",
            area: "yoshida",
            categories: ["furniture_appliances"],
            trade_method: "pickup",
          }
        end

        it "keeps the budget and drops the sell fields" do
          expect(listing_attributes).to eq(
            kind: "buy",
            item_name: "自行车",
            location: "桂校区",
            area: "yoshida",
            categories: ["furniture_appliances"],
            description: "",
            upload_ids: [],
            budget_min: 5000,
            budget_max: 10_000,
          )
        end
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:category)
    fab!(:photo) { Fabricate(:image_upload, user:) }

    let(:params) do
      {
        kind:,
        item_name:,
        price:,
        free:,
        location: "吉田本校区",
        area: "yoshida",
        categories: ["furniture_appliances"],
        trade_method: "pickup",
        description:,
        upload_ids: [photo.id],
      }
    end
    let(:dependencies) { { guardian: } }
    let(:guardian) { user.guardian }
    let(:kind) { "sell" }
    let(:item_name) { "宜家书桌" }
    let(:price) { 3000 }
    let(:free) { false }
    let(:description) { "九成新" }
    let(:topic) { result.new_post_result.post.topic }

    before do
      SiteSetting.kuu_market_enabled = true
      SiteSetting.kuu_market_category = category.id
      SiteSetting.default_locale = "zh_CN"
    end

    context "when the contract is invalid" do
      let(:kind) { "rent" }

      it { is_expected.to fail_a_contract }
    end

    context "when the market category is not set" do
      before { SiteSetting.kuu_market_category = "" }

      it { is_expected.to fail_to_find_a_model(:category) }
    end

    context "when the user cannot create topics in the market category" do
      before do
        category.set_permissions(everyone: :readonly)
        category.save!
      end

      it { is_expected.to fail_a_policy(:can_create_topic_in_category) }
    end

    context "when a photo is someone else's secure upload" do
      fab!(:photo) { Fabricate(:image_upload, user: Fabricate(:user), secure: true) }

      it { is_expected.to fail_a_policy(:photos_available_to_user) }
    end

    context "when a photo is someone else's public upload" do
      fab!(:photo) { Fabricate(:image_upload, user: Fabricate(:user)) }

      it { is_expected.to run_successfully }
    end

    context "when the listing is invalid" do
      let(:price) { nil }

      it { is_expected.to fail_with_an_invalid_model(:listing) }
    end

    context "when the user is posting too fast" do
      before do
        RateLimiter.enable
        create_post(user:, category:)
      end

      it { is_expected.to fail_with_exception(RateLimiter::LimitExceeded) }
    end

    context "when the post is rejected" do
      fab!(:watched_word) do
        Fabricate(:watched_word, word: "代写", action: WatchedWord.actions[:block])
      end

      let(:description) { "可以代写作业" }

      it { is_expected.to fail_a_step(:publish_listing) }

      it "does not create a listing" do
        expect { result }.not_to change { DiscourseKuuMarket::Listing.count }
      end
    end

    context "when new posts need approval" do
      fab!(:moderator)

      before { SiteSetting.approve_post_count = 1 }

      it { is_expected.to run_successfully }

      it "queues the post without creating a listing" do
        expect { result }.to change { ReviewableQueuedPost.count }.by(1)
        expect(result.new_post_result.action).to eq(:enqueued)
        expect(DiscourseKuuMarket::Listing.count).to eq(0)
      end

      it "creates the listing once the post is approved" do
        reviewable = result.new_post_result.reviewable
        reviewable.perform(moderator, :approve_post)

        expect(reviewable.reload.target.topic).to have_attributes(
          title: "【出售】宜家书桌 · ¥3,000",
          kuu_market_listing: have_attributes(kind: "sell", status: "selling", price: 3000),
        )
      end
    end

    context "with a buy listing" do
      let(:params) do
        {
          kind: "buy",
          item_name: "自行车",
          budget_max: 10_000,
          location: "桂校区",
          area: "katsura",
          categories: ["transport_sports"],
        }
      end

      it { is_expected.to run_successfully }

      it "creates a buying listing" do
        expect(topic).to have_attributes(
          title: "【求购】自行车 · ¥10,000 以内",
          category:,
          kuu_market_listing:
            have_attributes(kind: "buy", status: "buying", budget_max: 10_000, upload_ids: []),
        )
      end
    end

    context "with a short title that is already used" do
      fab!(:existing_topic) do
        Fabricate(:topic_with_op, category:).tap { |t| t.update_columns(title: "【赠送】伞") }
      end

      let(:item_name) { "伞" }
      let(:free) { true }

      it { is_expected.to run_successfully }

      it "publishes the listing with the generated title" do
        expect { result }.to change { Topic.where(title: "【赠送】伞").count }.by(1)
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "creates a topic in the market category with the generated title" do
        expect { result }.to change { category.topics.count }.by(1)
        expect(topic).to have_attributes(title: "【出售】宜家书桌 · ¥3,000", user:)
      end

      it "generates the first post" do
        expect(topic.first_post.raw).to include("- **价格**：¥3,000", "九成新")
      end

      it "creates a selling listing" do
        expect { result }.to change { DiscourseKuuMarket::Listing.count }.by(1)
        expect(topic.kuu_market_listing).to have_attributes(
          kind: "sell",
          status: "selling",
          item_name: "宜家书桌",
          price: 3000,
          free: false,
          location: "吉田本校区",
          area: "yoshida",
          categories: ["furniture_appliances"],
          trade_method: "pickup",
          description: "九成新",
          upload_ids: [photo.id],
          active_since: be_within(1.minute).of(Time.zone.now),
          last_bumped_at: be_within(1.minute).of(Time.zone.now),
        )
      end
    end
  end
end
