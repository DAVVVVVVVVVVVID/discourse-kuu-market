# frozen_string_literal: true

module DiscourseKuuMarket
  # 按表单内容生成标题和第一楼的 Markdown。正文是完整的帖子内容，
  # 邮件通知、搜索、RSS 和插件关掉以后都靠它显示
  class ListingRenderer
    MARKDOWN_SPECIAL_CHARS = /([\\`*_{}\[\]<>()#+\-.!|~])/

    def initialize(listing)
      @listing = listing
    end

    def title
      in_site_locale do
        if @listing.buy?
          t("title.buy", item: @listing.item_name, budget: budget)
        elsif @listing.free
          t("title.free", item: @listing.item_name)
        else
          t("title.sell", item: @listing.item_name, price: yen(@listing.price))
        end
      end
    end

    def raw
      in_site_locale do
        [photos_markdown, fields_markdown, @listing.description.strip].compact_blank.join("\n\n")
      end
    end

    private

    def photos_markdown
      uploads = Upload.where(id: @listing.upload_ids).index_by(&:id)
      images =
        @listing.upload_ids.filter_map do |id|
          uploads[id] && UploadMarkdown.new(uploads[id]).image_markdown(display_name: "")
        end
      return if images.empty?

      images.size > 1 ? ["[grid]", *images, "[/grid]"].join("\n") : images.first
    end

    def fields_markdown
      fields =
        if @listing.buy?
          { budget: budget }
        else
          { price: @listing.free ? t("free") : yen(@listing.price) }
        end
      fields[:location] = escape(@listing.location)
      fields[:trade_method] = t("trade_methods.#{@listing.trade_method}") if @listing.sell?

      fields.map { |name, value| t("field_line", label: t("fields.#{name}"), value:) }.join("\n")
    end

    def budget
      min, max = @listing.budget_min, @listing.budget_max

      if min && max
        min == max ? yen(min) : t("budget.range", min: delimited(min), max: delimited(max))
      elsif max
        t("budget.up_to", max: yen(max))
      else
        t("budget.from", min: yen(min))
      end
    end

    def yen(amount)
      t("yen", amount: delimited(amount))
    end

    def delimited(amount)
      ActiveSupport::NumberHelper.number_to_delimited(amount)
    end

    def escape(text)
      text.to_s.gsub(MARKDOWN_SPECIAL_CHARS, '\\\\\1')
    end

    def t(key, **args)
      I18n.t("kuu_market.listing.#{key}", **args)
    end

    def in_site_locale(&)
      I18n.with_locale(SiteSetting.default_locale, &)
    end
  end
end
