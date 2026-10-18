# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::ListingsController do
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:moderator)
  fab!(:stranger, :user)
  fab!(:market, :category)
  fab!(:topic) { Fabricate(:topic, user: author, category: market) }
  fab!(:first_post) { Fabricate(:post, topic:, user: author) }
  fab!(:listing) do
    Fabricate(:kuu_market_listing, topic:, active_since: 10.days.ago, last_bumped_at: 10.days.ago)
  end

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
  end

  def change_status(status)
    put "/kuu-market/listings/#{topic.id}/status.json", params: { status: }
  end

  describe "#update_status" do
    it "requires login" do
      change_status("sold")

      expect(response.status).to eq(403)
    end

    context "when signed in as the author" do
      before { sign_in(author) }

      it "marks the listing as sold, quietly closing and hiding the topic" do
        expect { change_status("sold") }.not_to change { topic.posts.count }

        expect(response.status).to eq(200)
        expect(response.parsed_body["listing"]["status"]).to eq("sold")
        expect(response.parsed_body["bumped"]).to eq(false)
        expect(topic.reload).to have_attributes(closed: true, visible: false)
      end

      it "puts a sold listing back on sale, bumping it to the top of Latest" do
        change_status("sold")
        freeze_time

        change_status("selling")

        expect(response.parsed_body["bumped"]).to eq(true)
        expect(topic.reload).to have_attributes(closed: false, visible: true)
        expect(topic.bumped_at).to eq_time(Time.zone.now)
        expect(listing.reload.active_since).to eq_time(Time.zone.now)
      end

      it "relists without bumping within the bump interval, and says when it can bump again" do
        listing.update!(last_bumped_at: 2.days.ago)
        change_status("sold")
        bumped_at = topic.reload.bumped_at

        change_status("selling")

        expect(response.parsed_body["bumped"]).to eq(false)
        expect(Time.zone.parse(response.parsed_body["listing"]["next_bump_at"])).to eq_time(
          listing.reload.last_bumped_at + 7.days,
        )
        expect(topic.reload.bumped_at).to eq_time(bumped_at)
        expect(listing.active_since).to be_within(1.minute).of(Time.zone.now)
      end

      it "cannot mark a listing as expired" do
        change_status("expired")

        expect(response.status).to eq(400)
        expect(listing.reload.status).to eq("selling")
      end

      it "cannot switch to the current status or to the other kind's status" do
        change_status("selling")
        expect(response.status).to eq(422)

        change_status("closed")
        expect(response.status).to eq(422)
      end

      it "can relist an expired listing" do
        listing.update!(status: "expired")

        change_status("selling")

        expect(response.status).to eq(200)
      end

      it "works long after the post edit time limit" do
        SiteSetting.post_edit_time_limit = 1
        first_post.update_columns(created_at: 3.days.ago)

        change_status("sold")

        expect(response.status).to eq(200)
      end

      it "ignores listings moved out of the market" do
        topic.update!(category: Fabricate(:category))

        change_status("sold")

        expect(response.status).to eq(404)
      end
    end

    it "lets staff change the status" do
      sign_in(moderator)

      change_status("sold")

      expect(response.status).to eq(200)
    end

    it "does not let other users change the status" do
      sign_in(stranger)

      change_status("sold")

      expect(response.status).to eq(403)
      expect(listing.reload.status).to eq("selling")
    end
  end
end
