# frozen_string_literal: true

module DiscourseKuuMarket
  # 插件的表单正在发帖或改帖。期间允许修改二手帖的第一楼和标题（见 EditRules），
  # 并且生成的标题可以过短、重名：「【赠送】伞」过不了 core 的最短长度、标题质量、
  # 不能重名三条检查，只对这个标题去掉这三类错误，屏蔽词等其他检查照常
  class FormSubmission < ActiveSupport::CurrentAttributes
    attribute :title

    LENGTH_ERRORS = %i[too_short].freeze
    QUALITY_ERRORS = %i[
      is_invalid
      is_invalid_meaningful
      is_invalid_unpretentious
      is_invalid_quiet
    ].freeze
    DUPLICATE_ERROR = :topic_title_already_used

    def self.submit(title, &)
      set(title:, &)
    end

    def self.active?
      title.present?
    end

    def self.forgive_title_errors(topic)
      return if !active? || topic.title != title

      (LENGTH_ERRORS + QUALITY_ERRORS).each { |type| topic.errors.delete(:title, type) }
      topic.errors.delete(:base, DUPLICATE_ERROR)
    end
  end
end
