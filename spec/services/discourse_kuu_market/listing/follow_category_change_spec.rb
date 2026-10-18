# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::Listing::FollowCategoryChange do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:market, :category)
    fab!(:other_category, :category)
    fab!(:topic) { Fabricate(:topic, user: author, category: market) }
    fab!(:first_post) { Fabricate(:post, topic:, user: author) }
    fab!(:listing) { Fabricate(:kuu_market_listing, topic:) }

    let(:params) { { topic_id: } }
    let(:dependencies) { {} }
    let(:topic_id) { topic.id }

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
    end

    context "when the contract is invalid" do
      let(:topic_id) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the topic has no listing" do
      fab!(:ordinary_topic) { Fabricate(:topic, category: market) }

      let(:topic_id) { ordinary_topic.id }

      it { is_expected.to fail_to_find_a_model(:listing) }
    end

    context "when the topic was moved out of the market" do
      before { topic.update_columns(category_id: other_category.id) }

      it { is_expected.to run_successfully }

      it "reopens and shows the topic" do
        expect { result }.to change { topic.reload.slice(:closed, :visible) }.from(
          "closed" => true,
          "visible" => false,
        ).to("closed" => false, "visible" => true)
      end

      it "clears the plugin's flags" do
        expect { result }.to change {
          listing.reload.slice(:closed_by_plugin, :unlisted_by_plugin)
        }.from("closed_by_plugin" => true, "unlisted_by_plugin" => true).to(
          "closed_by_plugin" => false,
          "unlisted_by_plugin" => false,
        )
      end
    end

    context "when the topic was moved back into the market" do
      before do
        topic.update_columns(category_id: other_category.id)
        described_class.call(params: { topic_id: topic.id })
        topic.update_columns(category_id: market.id)
      end

      it { is_expected.to run_successfully }

      it "closes and hides the topic again" do
        expect { result }.to change { topic.reload.slice(:closed, :visible) }.from(
          "closed" => false,
          "visible" => true,
        ).to("closed" => true, "visible" => false)
      end

      it "sets the plugin's flags again" do
        expect { result }.to change {
          listing.reload.slice(:closed_by_plugin, :unlisted_by_plugin)
        }.from("closed_by_plugin" => false, "unlisted_by_plugin" => false).to(
          "closed_by_plugin" => true,
          "unlisted_by_plugin" => true,
        )
      end
    end
  end
end
