import Component from "@glimmer/component";
import { action, get, set } from "@ember/object";
import { longDate } from "discourse/lib/formatter";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";
import ListingActions from "./listing-actions";
import RaisedHands from "./raised-hands";

// 帖子页标题下方：所有人看到状态、举手排队和成交对象；作者和管理员看到过期时间、切换状态和「修改」按钮
export default class ListingPanel extends Component {
  // 用 get 读：举手后 set 进来的新值，以及帖子重新加载时的新值，才会重新渲染
  get listing() {
    return get(this.args.outletArgs.model, "kuu_market_listing");
  }

  get statusLabel() {
    return i18n(`kuu_market.statuses.${this.listing.status}`);
  }

  // 只有进行中的帖子带 raised_hands；排队为空时也要显示按钮
  get showHands() {
    return Array.isArray(this.listing.raised_hands);
  }

  get expiresOn() {
    return this.listing.expires_at && longDate(this.listing.expires_at);
  }

  // 举手后不重新加载整个帖子，只换掉二手信息
  @action
  updateListing(listing) {
    set(this.args.outletArgs.model, "kuu_market_listing", listing);
  }

  <template>
    {{#if this.listing}}
      <div class="kuu-market-panel">
        <span
          class="kuu-market-panel__status kuu-market-status-{{this.listing.status}}"
        >
          {{this.statusLabel}}
        </span>

        {{#if this.listing.deal_user}}
          <span class="kuu-market-panel__deal">
            {{i18n "kuu_market.panel.deal.partner"}}
            <a
              class="trigger-user-card kuu-market-panel__deal-user"
              data-user-card={{this.listing.deal_user.username}}
            >
              {{dAvatar this.listing.deal_user imageSize="small"}}
              {{this.listing.deal_user.username}}
            </a>
          </span>
        {{/if}}

        {{#if this.expiresOn}}
          <span class="kuu-market-panel__expiry">
            {{i18n "kuu_market.panel.expires_on" date=this.expiresOn}}
          </span>
        {{/if}}

        {{#if this.listing.can_manage}}
          <ListingActions @listing={{this.listing}} />
        {{/if}}

        {{#if this.showHands}}
          <RaisedHands
            @listing={{this.listing}}
            @onChange={{this.updateListing}}
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
