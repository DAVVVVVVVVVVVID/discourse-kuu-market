# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::Listing::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_inclusion_of(:kind).in_array(%w[sell buy]) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:editor) { author }
    fab!(:category)
    fab!(:photo) { Fabricate(:image_upload, user: author) }
    fab!(:new_photo) { Fabricate(:image_upload, user: author) }

    fab!(:listing) do
      SiteSetting.kuu_market_enabled = true
      SiteSetting.kuu_market_category = category.id
      SiteSetting.default_locale = "zh_CN"

      created =
        DiscourseKuuMarket::Listing::Create.call(
          params: {
            kind: "sell",
            item_name: "宜家书桌",
            price: 3000,
            location: "吉田本校区",
            area: "yoshida",
            categories: ["furniture_appliances"],
            trade_method: "pickup",
            description: "九成新",
            upload_ids: [photo.id],
          },
          guardian: author.guardian,
        )
      post = created.new_post_result.post
      post.update_columns(created_at: 3.days.ago, last_version_at: 3.days.ago)
      post.topic.kuu_market_listing
    end

    let(:params) do
      {
        topic_id:,
        kind:,
        item_name: "宜家书桌",
        price: 2000,
        location: "吉田本校区",
        area: "yoshida",
        categories: ["furniture_appliances"],
        trade_method: "delivery",
        description:,
        upload_ids:,
      }
    end
    let(:dependencies) { { guardian: } }
    let(:guardian) { editor.guardian }
    let(:topic_id) { listing.topic_id }
    let(:kind) { "sell" }
    let(:description) { "降价了" }
    let(:upload_ids) { [photo.id, new_photo.id] }
    let(:topic) { listing.topic }
    let(:first_post) { topic.first_post }

    before do
      SiteSetting.kuu_market_enabled = true
      SiteSetting.kuu_market_category = category.id
      SiteSetting.default_locale = "zh_CN"
      SiteSetting.post_edit_time_limit = 60
    end

    context "when the listing is not found" do
      let(:topic_id) { 0 }

      it { is_expected.to fail_to_find_a_model(:listing) }
    end

    context "when the contract is invalid" do
      let(:kind) { "rent" }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic was moved out of the market" do
      before { topic.update!(category: Fabricate(:category)) }

      it { is_expected.to fail_a_policy(:listing_in_market) }
    end

    context "when the editor is another user" do
      fab!(:editor) { Fabricate(:user, refresh_auto_groups: true) }

      let(:upload_ids) { [photo.id] }

      it { is_expected.to fail_a_policy(:can_edit_listing) }
    end

    context "when the editor is anonymous" do
      let(:guardian) { Guardian.new }
      let(:upload_ids) { [photo.id] }

      it { is_expected.to fail_a_policy(:can_edit_listing) }
    end

    context "when the author is silenced" do
      before { editor.update!(silenced_till: 1.day.from_now) }

      it { is_expected.to fail_a_policy(:can_edit_listing) }
    end

    context "when the topic is trashed" do
      before { topic.trash!(Discourse.system_user) }

      it { is_expected.to fail_a_policy(:can_edit_listing) }
    end

    context "when the kind is changed" do
      let(:kind) { "buy" }

      it { is_expected.to fail_a_policy(:kind_unchanged) }
    end

    context "with a new photo uploaded by someone else" do
      fab!(:other_photo) { Fabricate(:image_upload, secure: true) }

      let(:upload_ids) { [photo.id, other_photo.id] }

      it { is_expected.to fail_a_policy(:photos_available_to_editor) }
    end

    context "when staff edits someone else's listing" do
      fab!(:editor, :moderator)

      let(:upload_ids) { [photo.id] }

      it { is_expected.to run_successfully }

      it "records the revision by the staff member" do
        result
        expect(first_post.revisions.last.user).to eq(editor)
      end
    end

    context "when staff keeps the author's photos and adds their own" do
      fab!(:editor, :moderator)
      fab!(:staff_photo) { Fabricate(:image_upload, user: editor) }

      let(:upload_ids) { [photo.id, staff_photo.id] }

      it { is_expected.to run_successfully }

      it "saves both photos" do
        expect { result }.to change { listing.reload.upload_ids }.to([photo.id, staff_photo.id])
      end
    end

    context "when the revised listing is invalid" do
      let(:upload_ids) { [] }

      it { is_expected.to fail_with_an_invalid_model(:revised_listing) }
    end

    context "when the first post revision is rejected" do
      fab!(:watched_word) do
        Fabricate(:watched_word, word: "代写", action: WatchedWord.actions[:block])
      end

      let(:description) { "可以代写作业" }

      it { is_expected.to fail_a_step(:revise_first_post) }

      it "does not save the listing" do
        expect { result }.not_to change { listing.reload.attributes }
      end
    end

    context "when the listing is sold and the topic closed" do
      before do
        listing.update!(status: "sold")
        topic.update!(closed: true)
      end

      it { is_expected.to run_successfully }

      it "regenerates the title" do
        expect { result }.to change { topic.reload.title }.to("【出售】宜家书桌 · ¥2,000")
      end
    end

    context "when the listing was posted before campuses and categories existed" do
      before { listing.update_columns(area: nil, categories: []) }

      context "when the form leaves them out" do
        let(:params) { super().except(:area, :categories) }

        it { is_expected.to fail_a_contract }
      end

      context "when the form fills them in" do
        let(:params) { super().merge(area: "uji", categories: %w[electronics study]) }

        it "saves them" do
          expect { result }.to change { listing.reload.area }.from(nil).to("uji")
          expect(listing.categories).to eq(%w[electronics study])
        end
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "regenerates the title and first post" do
        expect { result }.to change { topic.reload.title }.to("【出售】宜家书桌 · ¥2,000")
        expect(first_post.reload.raw).to include("- **价格**：¥2,000", "- **交易方式**：可送")
        expect(first_post.raw).to end_with("降价了")
      end

      it "records a revision by the editor" do
        expect { result }.to change { first_post.reload.version }.by(1)
        expect(first_post.revisions.last.user).to eq(editor)
      end

      it "neither bumps the topic nor restarts the expiry clock" do
        expect { result }.not_to change { [topic.reload.bumped_at, listing.reload.active_since] }
      end

      it "saves the listing" do
        expect { result }.to change {
          listing.reload.attributes.slice("price", "trade_method", "description", "upload_ids")
        }.to(
          "price" => 2000,
          "trade_method" => "delivery",
          "description" => "降价了",
          "upload_ids" => [photo.id, new_photo.id],
        )
      end
    end
  end
end
