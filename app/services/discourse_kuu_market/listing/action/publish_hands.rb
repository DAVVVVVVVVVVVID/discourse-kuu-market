# frozen_string_literal: true

module DiscourseKuuMarket
  # 举手排队变了，正在看这个帖子的人刷新一下头像
  class Listing::Action::PublishHands < Service::ActionBase
    option :listing

    def call
      topic = listing.topic
      MessageBus.publish(
        "/topic/#{topic.id}",
        { reload_topic: true },
        topic.secure_audience_publish_messages,
      )
    end
  end
end
