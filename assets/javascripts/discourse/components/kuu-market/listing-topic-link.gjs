import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// 包在 core 话题列表标题（topic-list/topic-link）外面：二手帖的标题链接画成商品卡片
// （左图，右边商品名、价格、状态，Issue #1），其他帖子直接交回 core 的渲染（yield）。
// core 的两处调用都传了 raw-topic-link 类名和 focus / blur 处理，这里照抄，键盘浏览列表时的高亮才不会丢
export default class ListingTopicLink extends Component {
  @service siteSettings;

  get topic() {
    return this.args.outletArgs.topic;
  }

  get card() {
    return this.topic.kuu_market_card;
  }

  // 卡片图片左下角的校区小字（Issue #11）；上线前发的帖子没有
  get areaLabel() {
    const area = this.card.area;
    return area ? i18n(`kuu_market.area_short.${area}`) : null;
  }

  get isBuy() {
    return this.topic.kuu_market_kind === "buy";
  }

  // 求购一律用求购图；出售有照片用列表本来就有的缩略图，没有就用占位图。两张图都是站点设置
  get imageUrl() {
    if (this.isBuy) {
      return this.siteSettings.kuu_market_buy_image;
    }
    if (this.card.has_photos && this.topic.image_url) {
      return this.topic.image_url;
    }
    return this.siteSettings.kuu_market_placeholder_image;
  }

  // 已出 / 已购买不调淡（2026-10-21 David 定，Issue #5），只有过期的调淡
  get isExpired() {
    return this.topic.kuu_market_status === "expired";
  }

  get statusLabel() {
    return i18n(`kuu_market.card_statuses.${this.topic.kuu_market_status}`);
  }

  get url() {
    return this.topic.linked_post_number
      ? this.topic.urlForPostNumber(this.topic.linked_post_number)
      : this.topic.lastUnreadUrl;
  }

  @action
  highlightItem(event) {
    event.target.closest(".topic-list-item")?.classList.add("selected");
  }

  @action
  unhighlightItem(event) {
    event.target.closest(".topic-list-item")?.classList.remove("selected");
  }

  <template>
    {{~#if this.card~}}
      <a
        class="title raw-link raw-topic-link kuu-market-card
          {{if this.isExpired '--expired'}}"
        data-topic-id={{this.topic.id}}
        href={{this.url}}
        {{on "focus" this.highlightItem}}
        {{on "blur" this.unhighlightItem}}
      >
        <span class="kuu-market-card__image">
          {{#if this.imageUrl}}
            <img alt="" decoding="async" loading="lazy" src={{this.imageUrl}} />
          {{else}}
            {{dIcon (if this.isBuy "magnifying-glass" "cart-shopping")}}
          {{/if}}
          {{#if this.areaLabel}}
            <span class="kuu-market-card__area">{{this.areaLabel}}</span>
          {{/if}}
        </span>
        <span class="kuu-market-card__body">
          <span class="kuu-market-card__name">{{this.card.item_name}}</span>
          <span class="kuu-market-card__footer">
            <span class="kuu-market-card__price {{if this.card.free '--free'}}">
              {{this.card.price}}
            </span>
            <span
              class="kuu-market-card__status kuu-market-status-{{this.topic.kuu_market_status}}"
            >
              {{this.statusLabel}}
            </span>
          </span>
        </span>
        {{~#if this.topic.visited~}}
          <span class="sr-only">&nbsp;{{i18n "topic.sr_read"}}</span>
        {{~/if~}}
      </a>
    {{~else~}}
      {{yield}}
    {{~/if~}}
  </template>
}
