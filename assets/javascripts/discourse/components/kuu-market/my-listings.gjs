import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { longDate } from "discourse/lib/formatter";
import DButton from "discourse/ui-kit/d-button";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";
import ListingActions from "./listing-actions";
import ListingForm from "./modal/listing-form";

const GROUPS = [
  { key: "active", statuses: ["selling", "buying"] },
  { key: "dealt", statuses: ["sold", "closed"] },
  { key: "expired", statuses: ["expired"] },
];

// 「我的商品」页（Issue #12）：自己的二手帖按进行中 / 已成交 / 已过期分开看，每条带管理按钮。
// 管理按钮和帖子页是同一个组件（ListingActions），改完刷新本页
export default class MyListings extends Component {
  @service modal;
  @service siteSettings;

  @tracked selected = "active";

  get listings() {
    return this.args.listings ?? [];
  }

  get tabs() {
    return GROUPS.map(({ key, statuses }) => ({
      key,
      label: i18n(`kuu_market.my_listings.tabs.${key}`),
      count: this.listings.filter((listing) =>
        statuses.includes(listing.status)
      ).length,
      isSelected: key === this.selected,
    }));
  }

  get items() {
    const { statuses } = GROUPS.find(({ key }) => key === this.selected);
    return this.listings
      .filter((listing) => statuses.includes(listing.status))
      .map((listing) => ({
        listing,
        imageUrl: this.#imageUrl(listing),
        statusLabel: i18n(`kuu_market.card_statuses.${listing.status}`),
        postedOn: i18n("kuu_market.my_listings.posted_on", {
          date: longDate(listing.created_at),
        }),
        endsOn: this.#endsOn(listing),
        handsLabel:
          listing.hands_count > 0
            ? i18n(`kuu_market.hands.count.${listing.kind}`, {
                count: listing.hands_count,
              })
            : null,
      }));
  }

  @action
  select(key) {
    this.selected = key;
  }

  @action
  post() {
    this.modal.show(ListingForm, { model: {} });
  }

  // 和列表卡片一样：求购一律用求购图；出售用第一张照片，没有就用占位图
  #imageUrl(listing) {
    if (listing.kind === "buy") {
      return this.siteSettings.kuu_market_buy_image;
    }
    return listing.photo_url || this.siteSettings.kuu_market_placeholder_image;
  }

  #endsOn(listing) {
    if (listing.expires_at) {
      return i18n("kuu_market.panel.expires_on", {
        date: longDate(listing.expires_at),
      });
    }
    if (listing.expired_at) {
      return i18n("kuu_market.my_listings.expired_on", {
        date: longDate(listing.expired_at),
      });
    }
    return null;
  }

  <template>
    <section class="kuu-market-my-listings">
      <h2 class="kuu-market-my-listings__title">
        {{i18n "kuu_market.my_listings.title"}}
      </h2>
      {{#if this.listings.length}}
        <div class="kuu-market-my-listings__tabs" role="tablist">
          {{#each this.tabs as |tab|}}
            <DButton
              aria-selected={{if tab.isSelected "true" "false"}}
              class="btn-flat kuu-market-my-listings__tab
                {{if tab.isSelected '--selected'}}"
              data-tab={{tab.key}}
              role="tab"
              @action={{fn this.select tab.key}}
              @translatedLabel={{tab.label}}
            >
              <span class="kuu-market-my-listings__count">{{tab.count}}</span>
            </DButton>
          {{/each}}
        </div>

        {{#if this.items.length}}
          <ul class="kuu-market-my-listings__list">
            {{#each this.items as |item|}}
              <li
                class="kuu-market-my-listings__item"
                data-topic-id={{item.listing.topic_id}}
              >
                <a
                  class="kuu-market-my-listings__image"
                  href={{item.listing.url}}
                >
                  {{#if item.imageUrl}}
                    <img alt="" loading="lazy" src={{item.imageUrl}} />
                  {{/if}}
                </a>
                <div class="kuu-market-my-listings__body">
                  <a
                    class="kuu-market-my-listings__name"
                    href={{item.listing.url}}
                  >{{item.listing.item_name}}</a>
                  <div class="kuu-market-my-listings__meta">
                    <span
                      class="kuu-market-card__price
                        {{if item.listing.free '--free'}}"
                    >{{item.listing.card_price}}</span>
                    <span
                      class="kuu-market-card__status kuu-market-status-{{item.listing.status}}"
                    >{{item.statusLabel}}</span>
                    {{#if item.handsLabel}}
                      <span
                        class="kuu-market-my-listings__hands"
                      >{{item.handsLabel}}</span>
                    {{/if}}
                  </div>
                  <div class="kuu-market-my-listings__dates">
                    <span>{{item.postedOn}}</span>
                    {{#if item.endsOn}}
                      <span>{{item.endsOn}}</span>
                    {{/if}}
                  </div>
                  <ListingActions
                    class="kuu-market-my-listings__actions"
                    @listing={{item.listing}}
                  >
                    <DButton
                      class="btn-flat kuu-market-my-listings__open"
                      @href={{item.listing.url}}
                      @icon="arrow-right"
                      @label="kuu_market.my_listings.open"
                    />
                  </ListingActions>
                </div>
              </li>
            {{/each}}
          </ul>
        {{else}}
          <p class="kuu-market-my-listings__none">
            {{i18n "kuu_market.my_listings.none_in_tab"}}
          </p>
        {{/if}}
      {{else}}
        <DEmptyState
          @ctaAction={{this.post}}
          @ctaIcon="cart-shopping"
          @ctaLabel={{i18n "kuu_market.my_listings.post"}}
          @identifier="kuu-market-my-listings"
          @title={{i18n "kuu_market.my_listings.empty"}}
        />
      {{/if}}
    </section>
  </template>
}
