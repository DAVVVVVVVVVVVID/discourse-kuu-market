# frozen_string_literal: true

RSpec.describe DiscourseKuuMarket::ListingRenderer do
  fab!(:photo) { Fabricate(:image_upload, width: 800, height: 600) }
  fab!(:other_photo) { Fabricate(:image_upload, width: 600, height: 800) }

  subject(:renderer) { described_class.new(listing) }

  before { SiteSetting.default_locale = "zh_CN" }

  describe "#title" do
    context "when selling" do
      let(:listing) { Fabricate.build(:kuu_market_listing, item_name: "宜家书桌", price: 3000) }

      it { expect(renderer.title).to eq("【出售】宜家书桌 · ¥3,000") }
    end

    context "when selling for 0 yen without ticking free" do
      let(:listing) { Fabricate.build(:kuu_market_listing, price: 0) }

      it { expect(renderer.title).to eq("【出售】宜家书桌 · ¥0") }
    end

    context "when giving away" do
      let(:listing) do
        Fabricate.build(:kuu_market_listing, item_name: "电饭锅", price: nil, free: true)
      end

      it { expect(renderer.title).to eq("【赠送】电饭锅") }
    end

    context "when buying with a budget range" do
      let(:listing) do
        Fabricate.build(:kuu_market_buy_listing, budget_min: 5000, budget_max: 10_000)
      end

      it { expect(renderer.title).to eq("【求购】自行车 · ¥5,000–10,000") }
    end

    context "when buying with only a maximum" do
      let(:listing) do
        Fabricate.build(:kuu_market_buy_listing, budget_min: nil, budget_max: 10_000)
      end

      it { expect(renderer.title).to eq("【求购】自行车 · ¥10,000 以内") }
    end

    context "when buying with only a minimum" do
      let(:listing) { Fabricate.build(:kuu_market_buy_listing, budget_min: 5000, budget_max: nil) }

      it { expect(renderer.title).to eq("【求购】自行车 · ¥5,000 以上") }
    end

    context "when buying with the same minimum and maximum" do
      let(:listing) { Fabricate.build(:kuu_market_buy_listing, budget_min: 5000, budget_max: 5000) }

      it { expect(renderer.title).to eq("【求购】自行车 · ¥5,000") }
    end

    context "when the site is in English" do
      let(:listing) { Fabricate.build(:kuu_market_listing, item_name: "Desk", price: 1_234_567) }

      before { SiteSetting.default_locale = "en" }

      it "uses the site language, not the current user's" do
        I18n.with_locale(:zh_CN) { expect(renderer.title).to eq("[For sale] Desk · ¥1,234,567") }
      end
    end
  end

  describe "#title_prefix" do
    it "is the beginning of each kind of generated title" do
      expect(described_class.new(Fabricate.build(:kuu_market_listing)).title_prefix).to eq("【出售】")
      expect(
        described_class.new(
          Fabricate.build(:kuu_market_listing, price: nil, free: true),
        ).title_prefix,
      ).to eq("【赠送】")
      expect(described_class.new(Fabricate.build(:kuu_market_buy_listing)).title_prefix).to eq(
        "【求购】",
      )
    end

    it "uses the site language" do
      SiteSetting.default_locale = "en"

      expect(described_class.new(Fabricate.build(:kuu_market_listing)).title_prefix).to eq(
        "[For sale] ",
      )
    end

    it "matches the start of the title" do
      %i[kuu_market_listing kuu_market_buy_listing].each do |fabricator|
        renderer = described_class.new(Fabricate.build(fabricator))
        expect(renderer.title).to start_with(renderer.title_prefix)
      end
    end
  end

  describe "#card_price" do
    it "shows the price, a giveaway or the budget" do
      expect(
        described_class.new(Fabricate.build(:kuu_market_listing, price: 52_000)).card_price,
      ).to eq("¥52,000")
      expect(
        described_class.new(
          Fabricate.build(:kuu_market_listing, price: nil, free: true),
        ).card_price,
      ).to eq("赠送")
      expect(
        described_class.new(
          Fabricate.build(:kuu_market_buy_listing, budget_min: 0, budget_max: 2000),
        ).card_price,
      ).to eq("¥0–2,000")
      expect(
        described_class.new(
          Fabricate.build(:kuu_market_buy_listing, budget_min: nil, budget_max: 10_000),
        ).card_price,
      ).to eq("¥10,000 以内")
    end
  end

  describe "#hand_message" do
    fab!(:topic, :topic_with_op)

    context "when raising a hand on a sell listing" do
      let(:listing) do
        Fabricate.build(
          :kuu_market_listing,
          topic:,
          price: 3000,
          upload_ids: [photo.id, other_photo.id],
        )
      end

      it "shows the first photo, links the listing and greets the seller" do
        expect(renderer.hand_message(:raised)).to eq(<<~MD.strip)
          [![|800x600](#{photo.short_url})](#{topic.url})
          [【出售】宜家书桌 · ¥3,000](#{topic.url})
          同学您好！我想购买这件物品，可以咨询一下吗？
        MD
      end
    end

    context "when raising a hand on a buy listing without a reference photo" do
      let(:listing) do
        Fabricate.build(:kuu_market_buy_listing, topic:, budget_min: nil, budget_max: 10_000)
      end

      it "only links the listing" do
        expect(renderer.hand_message(:raised)).to eq(<<~MD.strip)
          [【求购】自行车 · ¥10,000 以内](#{topic.url})
          同学您好！我这里有你想要的物品，可以咨询一下吗？
        MD
      end
    end

    context "when lowering a hand" do
      let(:listing) { Fabricate.build(:kuu_market_listing, topic:, upload_ids: [photo.id]) }

      it "leaves out the photo" do
        expect(renderer.hand_message(:cancelled)).to eq(<<~MD.strip)
          [【出售】宜家书桌 · ¥3,000](#{topic.url})
          我暂时不需要了，取消购买请求
        MD
      end
    end

    context "when the item name contains Markdown" do
      let(:listing) { Fabricate.build(:kuu_market_buy_listing, topic:, item_name: "[书] 架") }

      it "keeps the link intact" do
        expect(renderer.hand_message(:cancelled)).to start_with("[【求购】\\[书\\] 架 · ¥5,000–10,000](")
      end
    end

    context "when the photo is private" do
      let(:listing) { Fabricate.build(:kuu_market_listing, topic:, upload_ids: [photo.id]) }

      before { photo.update!(secure: true) }

      it "leaves it out" do
        expect(renderer.hand_message(:raised)).to start_with("[【出售】")
      end
    end
  end

  describe "#raw" do
    context "when selling" do
      let(:listing) do
        Fabricate.build(
          :kuu_market_listing,
          price: 3000,
          location: "吉田本校区",
          area: "yoshida",
          categories: %w[furniture_appliances study],
          trade_method: "pickup",
          description: "九成新，用了一年。\n\n周末可以看货。",
          upload_ids: [photo.id],
        )
      end

      it "lists the photo, the fields and the description" do
        expect(renderer.raw).to eq(<<~MD.strip)
          ![|800x600](#{photo.short_url})

          - **价格**：¥3,000
          - **位置范围**：吉田校区
          - **交易地点**：吉田本校区
          - **交易方式**：自取
          - **商品分类**：家具家电、教材与学习

          九成新，用了一年。

          周末可以看货。
        MD
      end
    end

    context "with several photos" do
      let(:listing) { Fabricate.build(:kuu_market_listing, upload_ids: [other_photo.id, photo.id]) }

      it "puts them in a grid in the chosen order" do
        expect(renderer.raw).to start_with(<<~MD.strip)
          [grid]
          ![|600x800](#{other_photo.short_url})
          ![|800x600](#{photo.short_url})
          [/grid]
        MD
      end
    end

    context "when giving away" do
      let(:listing) do
        Fabricate.build(:kuu_market_listing, price: nil, free: true, trade_method: "delivery")
      end

      it "shows the giveaway as the price" do
        expect(renderer.raw).to include("- **价格**：免费赠送\n")
        expect(renderer.raw).to include("- **交易方式**：可送")
      end
    end

    context "when buying without a reference photo or description" do
      let(:listing) do
        Fabricate.build(
          :kuu_market_buy_listing,
          budget_min: nil,
          budget_max: 10_000,
          location: "桂校区",
          area: "katsura",
          description: "",
        )
      end

      it "only lists the budget, the place and the category" do
        expect(renderer.raw).to eq(<<~MD.strip)
          - **预算**：¥10,000 以内
          - **位置范围**：桂校区
          - **交易地点**：桂校区
          - **商品分类**：交通与运动
        MD
      end
    end

    context "when the listing was posted before campuses and categories existed" do
      let(:listing) { Fabricate.build(:kuu_market_listing, area: nil, categories: []) }

      it "leaves them out" do
        expect(renderer.raw).not_to include("位置范围")
        expect(renderer.raw).not_to include("商品分类")
      end
    end

    context "when the place typed by the user contains Markdown" do
      let(:listing) { Fabricate.build(:kuu_market_listing, location: "*百万遍* [路口](x)") }

      it "escapes it so the field list stays intact" do
        expect(renderer.raw).to include("- **交易地点**：\\*百万遍\\* \\[路口\\]\\(x\\)\n")
      end
    end

    context "when the description uses Markdown" do
      let(:listing) { Fabricate.build(:kuu_market_listing, description: "**成色**：几乎全新") }

      it "keeps it, like any other post" do
        expect(renderer.raw).to end_with("**成色**：几乎全新")
      end
    end

    context "when a photo no longer exists" do
      let(:listing) { Fabricate.build(:kuu_market_listing, upload_ids: [other_photo.id, photo.id]) }

      it "skips it" do
        other_photo.destroy!

        expect(renderer.raw).to start_with("![|800x600](#{photo.short_url})\n\n")
      end
    end
  end
end
