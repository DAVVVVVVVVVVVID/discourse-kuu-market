# frozen_string_literal: true

module DiscourseKuuMarket
  # 插件生成的标题短（「【赠送】伞」）、常常重名（两个人都送电饭锅），过不了 core 的
  # 最短长度、标题质量、不能重名三条检查。插件发帖或改帖期间记下生成的标题，
  # Topic 校验完以后只对这个标题去掉这三类错误，屏蔽词等其他检查照常
  class GeneratedTitle < ActiveSupport::CurrentAttributes
    attribute :title

    LENGTH_ERRORS = %i[too_short].freeze
    QUALITY_ERRORS = %i[
      is_invalid
      is_invalid_meaningful
      is_invalid_unpretentious
      is_invalid_quiet
    ].freeze
    DUPLICATE_ERROR = :topic_title_already_used

    def self.allow(title, &)
      set(title:, &)
    end

    def self.forgive_title_errors(topic)
      return if title.blank? || topic.title != title

      (LENGTH_ERRORS + QUALITY_ERRORS).each { |type| topic.errors.delete(:title, type) }
      topic.errors.delete(:base, DUPLICATE_ERROR)
    end
  end
end
