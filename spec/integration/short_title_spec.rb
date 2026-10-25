# frozen_string_literal: true

# 插件生成的标题可能很短（「【赠送】伞」），过不了 core 的最短标题长度。表单发帖、改帖时插件放宽了，
# 但 core 改分类等路径也会重新检查标题（搭子插件发现的，二手 Issue #19）
RSpec.describe "Listings with short generated titles" do
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:market, :category)
  fab!(:other_category, :category)
  fab!(:photo) { Fabricate(:image_upload, user: author) }

  let(:topic) do
    DiscourseKuuMarket::Listing::Create
      .call(
        params: {
          kind: "sell",
          item_name: "伞",
          free: true,
          location: "吉田本校区",
          area: "yoshida",
          categories: ["other"],
          trade_method: "pickup",
          upload_ids: [photo.id],
        },
        guardian: author.guardian,
      )
      .new_post_result
      .post
      .topic
  end

  before do
    SiteSetting.kuu_market_enabled = true
    SiteSetting.kuu_market_category = market.id
    SiteSetting.default_locale = "zh_CN"
    SiteSetting.min_topic_title_length = 15
  end

  it "is shorter than the minimum title length" do
    expect(topic.title).to eq("【赠送】伞")
    expect(topic.title.length).to be < SiteSetting.min_topic_title_length
  end

  it "can be moved to another category and back by staff" do
    sign_in(admin)

    put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: other_category.id }
    expect(response.status).to eq(200)
    expect(topic.reload.category_id).to eq(other_category.id)

    put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: market.id }
    expect(response.status).to eq(200)
    expect(topic.reload.category_id).to eq(market.id)
  end

  it "can change status" do
    result =
      DiscourseKuuMarket::Listing::ChangeStatus.call(
        params: {
          topic_id: topic.id,
          status: "sold",
        },
        guardian: author.guardian,
      )

    expect(result).to run_successfully
    expect(topic.reload).to have_attributes(closed: true, visible: false)
  end

  it "lets staff edit the first post with the normal editor" do
    sign_in(admin)

    put "/posts/#{topic.first_post.id}.json", params: { post: { raw: "管理员删掉了手机号" } }

    expect(response.status).to eq(200)
    expect(topic.first_post.reload.raw).to eq("管理员删掉了手机号")
  end

  it "still rejects staff renaming it to another title that is too short" do
    sign_in(admin)

    put "/t/#{topic.slug}/#{topic.id}.json", params: { title: "短标题" }

    expect(response.status).to eq(422)
  end
end
