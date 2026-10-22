# frozen_string_literal: true

module PageObjects
  module Modals
    # 发帖和修改共用的二手帖表单
    class KuuMarketListingForm < PageObjects::Modals::Base
      MODAL_SELECTOR = ".kuu-market-form-modal"

      def initialize
        super(modal_selector: MODAL_SELECTOR)
      end

      def form
        PageObjects::Components::FormKit.new("#{MODAL_SELECTOR} .kuu-market-form")
      end

      def field(name)
        form.field(name)
      end

      def choose_kind(kind)
        field("kind").select(kind)
        self
      end

      def choose_area(area)
        field("area").select(area)
        self
      end

      def category_chip(key)
        find("#{MODAL_SELECTOR} .kuu-market-chips__chip[data-category='#{key}']")
      end

      def pick_categories(*keys)
        keys.each { category_chip(it).click }
        self
      end

      def fill_in(name, value)
        field(name).fill_in(value)
        self
      end

      def upload_photo(file)
        attach_file(file.path) { find("#{MODAL_SELECTOR} .kuu-market-photos__add").click }
        has_css?("#{MODAL_SELECTOR} .kuu-market-photos__item", wait: 10)
        self
      end

      def has_photos?(count)
        has_css?("#{MODAL_SELECTOR} .kuu-market-photos__item", count:)
      end

      def remove_first_photo
        first("#{MODAL_SELECTOR} .kuu-market-photos__remove").click
        self
      end

      def submit
        find("#{MODAL_SELECTOR} .kuu-market-form-modal__submit").click
      end

      def has_field_error?(name)
        has_css?("#{MODAL_SELECTOR} .form-kit__field[data-name='#{name}'] .form-kit__errors")
      end

      def has_flash?(text)
        has_css?("#{MODAL_SELECTOR} .alert-error", text:)
      end
    end
  end
end
