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

  describe ".open" do
    it "starts a listing for sale or wanted from now" do
      freeze_time

      sell = described_class.open(kind: "sell")
      buy = described_class.open(kind: "buy")

      expect(sell.status).to eq("selling")
      expect(sell.active_since).to eq_time(Time.zone.now)
      expect(sell.last_bumped_at).to eq_time(Time.zone.now)
      expect(buy.status).to eq("buying")
    end

    it "leaves the status empty for an unknown kind" do
      expect(described_class.open(kind: nil).status).to be_nil
    end
  end

  describe "#can_change_to?" do
    it "moves between in progress and ended, and out of expired" do
      sell = Fabricate.build(:kuu_market_listing, status: "selling")
      expect(sell.can_change_to?("sold")).to eq(true)
      expect(sell.can_change_to?("selling")).to eq(false)

      expired = Fabricate.build(:kuu_market_buy_listing, status: "expired")
      expect(expired.can_change_to?("buying")).to eq(true)
      expect(expired.can_change_to?("closed")).to eq(true)
    end

    it "never moves to expired or to the other kind's statuses" do
      sell = Fabricate.build(:kuu_market_listing, status: "selling")

      expect(sell.can_change_to?("expired")).to eq(false)
      expect(sell.can_change_to?("closed")).to eq(false)
    end
  end

  describe "#change_status" do
    it "restarts the expiry clock when back in progress" do
      listing = Fabricate.build(:kuu_market_listing, status: "sold", active_since: 40.days.ago)

      listing.change_status("selling", at: Time.zone.parse("2026-10-18 12:00"))

      expect(listing.active_since).to eq_time(Time.zone.parse("2026-10-18 12:00"))
    end

    it "keeps the expiry clock when ending" do
      listing = Fabricate.build(:kuu_market_listing, active_since: 10.days.ago)

      expect { listing.change_status("sold") }.not_to change { listing.active_since }
    end
  end

  describe "#bump_due?" do
    before { SiteSetting.kuu_market_bump_interval_days = 7 }

    it "allows one bump per interval" do
      freeze_time

      expect(Fabricate.build(:kuu_market_listing, last_bumped_at: 7.days.ago)).to be_bump_due
      expect(
        Fabricate.build(:kuu_market_listing, last_bumped_at: 7.days.ago + 1.second),
      ).not_to be_bump_due
    end
  end

  describe "#closes_replies?" do
    it "is true only for sold and closed listings" do
      expect(Fabricate.build(:kuu_market_listing, status: "sold")).to be_closes_replies
      expect(Fabricate.build(:kuu_market_buy_listing, status: "closed")).to be_closes_replies
      expect(Fabricate.build(:kuu_market_listing, status: "expired")).not_to be_closes_replies
      expect(Fabricate.build(:kuu_market_listing, status: "selling")).not_to be_closes_replies
    end
  end

  describe ".photos_usable_by?" do
    fab!(:user)

    it "accepts the user's own uploads and anyone's public uploads" do
      own = Fabricate(:upload, user:, secure: true)
      public_upload = Fabricate(:upload)

      expect(described_class.photos_usable_by?(user, [own.id, public_upload.id])).to eq(true)
    end

    it "rejects someone else's secure uploads and missing ones" do
      secure = Fabricate(:upload, secure: true)

      expect(described_class.photos_usable_by?(user, [secure.id])).to eq(false)
      expect(described_class.photos_usable_by?(user, [-42])).to eq(false)
    end

    it "accepts no photos" do
      expect(described_class.photos_usable_by?(user, [])).to eq(true)
    end
  end

  describe "photos" do
    it "only accepts existing image uploads" do
      SiteSetting.authorized_extensions = "png|pdf"
      pdf = Fabricate(:upload, original_filename: "manual.pdf", extension: "pdf")
      deleted = Fabricate(:upload).tap(&:destroy!)

      expect(Fabricate.build(:kuu_market_listing, upload_ids: [pdf.id])).not_to be_valid
      expect(Fabricate.build(:kuu_market_listing, upload_ids: [deleted.id])).not_to be_valid
    end

    it "rejects the same photo twice" do
      photo = Fabricate(:upload)

      expect(Fabricate.build(:kuu_market_listing, upload_ids: [photo.id, photo.id])).not_to be_valid
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
