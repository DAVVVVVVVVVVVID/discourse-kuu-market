# frozen_string_literal: true

# name: discourse-kuu-market
# about: 二手市场：用专门的表单发出售 / 求购帖，作者可以标记状态，成交和过期的帖子不再出现在别人的列表和搜索里
# version: 0.0.1
# authors: DAVVVVVVVVVVVID
# url: https://github.com/DAVVVVVVVVVVVID/discourse-kuu-market
# required_version: 2026.1.0

enabled_site_setting :kuu_market_enabled

module ::DiscourseKuuMarket
  PLUGIN_NAME = "discourse-kuu-market"
end

require_relative "lib/discourse_kuu_market/engine"

after_initialize {}
