# frozen_string_literal: true

module DiscourseKuuMarket
  # 二手帖的第一楼和标题由表单生成，表单字段是唯一来源。作者用普通编辑器改的话，
  # 正文和表单就对不上了，所以只能用表单改；管理员照常能用普通编辑器（比如删掉手机号），
  # 作者下次用表单修改时正文按表单重新生成
  module EditRules
    def self.check_post(post)
      return if !editing_by_hand?(post)
      return if !post.is_first_post? || !post.will_save_change_to_raw?
      return if !Listing.exists?(topic_id: post.topic_id)

      post.errors.add(:base, I18n.t("kuu_market.errors.edit_with_market_form"))
    end

    def self.check_topic(topic)
      return if !editing_by_hand?(topic)
      return if !topic.will_save_change_to_title?
      return if !Listing.exists?(topic_id: topic.id)

      topic.errors.add(:base, I18n.t("kuu_market.errors.edit_with_market_form"))
    end

    # 只管用户发起的编辑（PostRevisor 会设 acting_user）；core 自己的改动（比如换上传链接）不拦
    def self.editing_by_hand?(record)
      record.persisted? && !FormSubmission.active? && record.acting_user.present? &&
        !record.acting_user.staff?
    end
  end
end
