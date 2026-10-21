# frozen_string_literal: true

class AddAlertedAtToKuuMarketRaisedHands < ActiveRecord::Migration[8.1]
  def change
    # 发帖人在弹窗里看过这次举手的时间（Issue #5 第二期），没看过的才弹
    add_column :kuu_market_raised_hands, :alerted_at, :datetime
  end
end
