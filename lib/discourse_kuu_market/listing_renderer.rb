# frozen_string_literal: true

module DiscourseKuuMarket
  # 按表单内容生成标题和第一楼的 Markdown。正文是完整的帖子内容，
  # 邮件通知、搜索、RSS 和插件关掉以后都靠它显示
  class ListingRenderer
    MARKDOWN_SPECIAL_CHARS = /([\\`*_{}\[\]<>()#+\-.!|~])/
    PREFIX_MARKER = "\u0000"

    def initialize(listing)
      @listing = listing
    end

    def title
      in_site_locale do
        case title_key
        when "buy"
          t("title.buy", item: @listing.item_name, budget: budget)
        when "free"
          t("title.free", item: @listing.item_name)
        else
          t("title.sell", item: @listing.item_name, price: yen(@listing.price))
        end
      end
    end

    # 标题开头的「【出售】」「【赠送】」「【求购】」，前端拿它把前缀单独上色
    def title_prefix
      in_site_locale do
        t("title.#{title_key}", item: PREFIX_MARKER, price: "", budget: "").split(
          PREFIX_MARKER,
        ).first
      end
    end

    # 列表卡片上的价格：出售「¥52,000」、赠送「赠送」、求购是预算（和标题里的写法一样）
    def card_price
      in_site_locale do
        case title_key
        when "buy"
          budget
        when "free"
          t("card.free")
        else
          yen(@listing.price)
        end
      end
    end

    def raw
      in_site_locale do
        [photos_markdown, fields_markdown, @listing.description.strip].compact_blank.join("\n\n")
      end
    end

    private

    def title_key
      return "buy" if @listing.buy?
      @listing.free ? "free" : "sell"
    end

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
