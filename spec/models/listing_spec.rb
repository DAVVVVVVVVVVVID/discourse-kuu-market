# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::Listing do
  it "is valid as fabricated" do
    expect(Fabricate.build(:kuu_market_listing)).to be_valid
    expect(Fabricate.build(:kuu_market_buy_listing)).to be_valid
  end

  it "allows one listing per topic" do
    listing = Fabricate(:kuu_market_listing)
    duplicate = Fabricate.build(:kuu_market_listing, topic: listing.topic)

    expect(duplicate).not_to be_valid
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe "statuses" do
    it "allows the statuses that belong to each kind" do
      %w[selling sold expired].each do |status|
        expect(Fabricate.build(:kuu_market_listing, status:)).to be_valid
      end
      %w[buying closed expired].each do |status|
        expect(Fabricate.build(:kuu_market_buy_listing, status:)).to be_valid
      end
    end

    it "rejects a status of the other kind" do
      expect(Fabricate.build(:kuu_market_listing, status: "buying")).not_to be_valid
      expect(Fabricate.build(:kuu_market_buy_listing, status: "sold")).not_to be_valid
    end

    it "rejects a status of the other kind at the database level" do
      listing = Fabricate.build(:kuu_market_listing, status: "closed")

      expect { listing.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it "rejects unknown kinds and statuses" do
      expect(Fabricate.build(:kuu_market_listing, kind: "rent")).not_to be_valid
      expect(Fabricate.build(:kuu_market_listing, status: "reserved")).not_to be_valid
    end

    it "knows the in-progress and ended status of each kind" do
      expect(described_class.active_status_for(:sell)).to eq("selling")
      expect(described_class.ended_status_for(:sell)).to eq("sold")
      expect(described_class.active_status_for(:buy)).to eq("buying")
      expect(described_class.ended_status_for(:buy)).to eq("closed")
    end

    it "is active only while for sale or wanted" do
      expect(Fabricate.build(:kuu_market_listing, status: "selling")).to be_active
      expect(Fabricate.build(:kuu_market_buy_listing, status: "buying")).to be_active
      expect(Fabricate.build(:kuu_market_listing, status: "sold")).not_to be_active
      expect(Fabricate.build(:kuu_market_buy_listing, status: "expired")).not_to be_active
    end
  end

  describe "sell listings" do
    it "needs a price unless it is free" do
      expect(Fabricate.build(:kuu_market_listing, price: nil)).not_to be_valid
      expect(Fabricate.build(:kuu_market_listing, price: nil, free: true)).to be_valid
      expect(Fabricate.build(:kuu_market_listing, price: 0)).to be_valid
    end

    it "rejects negative and absurd prices" do
      expect(Fabricate.build(:kuu_market_listing, price: -1)).not_to be_valid
      expect(
        Fabricate.build(:kuu_market_listing, price: described_class::MAX_YEN + 1),
      ).not_to be_valid
    end

    it "needs a trade method" do
      expect(Fabricate.build(:kuu_market_listing, trade_method: nil)).not_to be_valid
      expect(Fabricate.build(:kuu_market_listing, trade_method: "airdrop")).not_to be_valid
    end

    it "needs at least one photo and at most the configured number" do
      SiteSetting.kuu_market_max_photos = 2
      uploads = Fabricate.times(3, :upload).map(&:id)

      expect(Fabricate.build(:kuu_market_listing, upload_ids: [])).not_to be_valid
      expect(Fabricate.build(:kuu_market_listing, upload_ids: uploads.first(2))).to be_valid
      expect(Fabricate.build(:kuu_market_listing, upload_ids: uploads)).not_to be_valid
    end

    it "has no budget" do
      expect(Fabricate.build(:kuu_market_listing, budget_max: 100)).not_to be_valid
    end
  end

  describe "buy listings" do
    it "needs at least one end of the budget" do
      expect(Fabricate.build(:kuu_market_buy_listing, budget_min: nil)).to be_valid
      expect(Fabricate.build(:kuu_market_buy_listing, budget_max: nil)).to be_valid
      expect(
        Fabricate.build(:kuu_market_buy_listing, budget_min: nil, budget_max: nil),
      ).not_to be_valid
    end

    it "rejects a budget whose minimum is above its maximum" do
      expect(
        Fabricate.build(:kuu_market_buy_listing, budget_min: 10_000, budget_max: 5000),
      ).not_to be_valid
    end

    it "allows at most one reference photo" do
      uploads = Fabricate.times(2, :upload).map(&:id)

      expect(Fabricate.build(:kuu_market_buy_listing, upload_ids: uploads.first(1))).to be_valid
      expect(Fabricate.build(:kuu_market_buy_listing, upload_ids: uploads)).not_to be_valid
    end

    it "has no price, giveaway or trade method" do
      expect(Fabricate.build(:kuu_market_buy_listing, price: 100)).not_to be_valid
      expect(Fabricate.build(:kuu_market_buy_listing, free: true)).not_to be_valid
      expect(Fabricate.build(:kuu_market_buy_listing, trade_method: "pickup")).not_to be_valid
    end
  end

  it "limits the length of the text fields" do
    expect(
      Fabricate.build(
        :kuu_market_listing,
        item_name: "a" * (described_class::ITEM_NAME_MAX_LENGTH + 1),
      ),
    ).not_to be_valid
    expect(
      Fabricate.build(
        :kuu_market_listing,
        location: "a" * (described_class::LOCATION_MAX_LENGTH + 1),
      ),
    ).not_to be_valid
    expect(
      Fabricate.build(
        :kuu_market_listing,
        description: "a" * (described_class::DESCRIPTION_MAX_LENGTH + 1),
      ),
    ).not_to be_valid
  end
end
