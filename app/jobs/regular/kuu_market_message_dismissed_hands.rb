# frozen_string_literal: true

module Jobs
  # 成交后以作者的身份私聊告诉其他举手人「已售出 / 已经收到东西」。人多时私聊要发好几条，
  # 放到后台做，不拖慢「标记已出」
  class KuuMarketMessageDismissedHands < ::Jobs::Base
    def execute(args)
      listing =
        DiscourseKuuMarket::Listing.includes(topic: :user).find_by(topic_id: args[:topic_id])
      author = listing&.topic&.user
      return if author.nil?

      message = DiscourseKuuMarket::ListingRenderer.new(listing).hand_message(:dealt)
      User
        .where(id: args[:user_ids])
        .find_each do |recipient|
          DiscourseKuuMarket::Listing::Action::SendDirectMessage.call(
            sender: author,
            recipient:,
            message:,
          )
        end
    end
  end
end
