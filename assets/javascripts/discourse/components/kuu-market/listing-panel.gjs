import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action, get, set } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { longDate } from "discourse/lib/formatter";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";
import DealPicker from "./modal/deal-picker";
import ListingForm from "./modal/listing-form";
import RaisedHands from "./raised-hands";

// 帖子页标题下方：所有人看到状态、举手排队和成交对象；作者和管理员看到过期时间、切换状态和「修改」按钮
export default class ListingPanel extends Component {
  @service dialog;
  @service modal;
  @service router;
  @service siteSettings;
  @service toasts;

  @tracked changingTo = null;

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

  get isChanging() {
    return !!this.changingTo;
  }

  get expiresOn() {
    return this.listing.expires_at && longDate(this.listing.expires_at);
  }

  @action
  actionLabel(status) {
    return `kuu_market.panel.change_to.${status}`;
  }

  @action
  changeStatus(status) {
    if (this.#endsListing(status) && this.listing.raised_hands?.length) {
      this.modal.show(DealPicker, {
        model: {
          listing: this.listing,
          onConfirm: (dealUserId) => this.#saveStatus(status, dealUserId),
        },
      });
    } else if (this.#endsListing(status)) {
      this.dialog.yesNoConfirm({
        message: i18n(`kuu_market.panel.confirm_end.${this.listing.kind}`),
        didConfirm: () => this.#saveStatus(status),
      });
    } else {
      this.#saveStatus(status);
    }
  }

  // 举手后不重新加载整个帖子，只换掉二手信息
  @action
  updateListing(listing) {
    set(this.args.outletArgs.model, "kuu_market_listing", listing);
  }

  @action
  edit() {
    this.modal.show(ListingForm, { model: { listing: this.listing } });
  }

  #endsListing(status) {
    return status === "sold" || status === "closed";
  }

  async #saveStatus(status, dealUserId = null) {
    this.changingTo = status;

    try {
      const data = { status };
      if (dealUserId) {
        data.deal_user_id = dealUserId;
      }
      const result = await ajax(
        `/kuu-market/listings/${this.listing.topic_id}/status.json`,
        { type: "PUT", data }
      );
      this.#announce(status, result);
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.changingTo = null;
    }
  }

  #announce(status, { listing, bumped }) {
    let message;
    if (this.#endsListing(status)) {
      message = i18n("kuu_market.panel.ended");
    } else if (bumped) {
      message = i18n("kuu_market.panel.relisted_and_bumped");
    } else {
      message = i18n("kuu_market.panel.relisted_without_bump", {
        date: longDate(listing.next_bump_at),
        days: this.siteSettings.kuu_market_bump_interval_days,
      });
    }

    this.toasts.success({ duration: "long", data: { message } });
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
          <div class="kuu-market-panel__actions">
            {{#each this.listing.statuses_reachable as |status|}}
              <DButton
                class="btn-default kuu-market-panel__change"
                data-status={{status}}
                @action={{fn this.changeStatus status}}
                @disabled={{this.isChanging}}
                @isLoading={{eq this.changingTo status}}
                @label={{this.actionLabel status}}
              />
            {{/each}}
            <DButton
              class="btn-default kuu-market-panel__edit"
              @action={{this.edit}}
              @icon="pencil"
              @label="kuu_market.panel.edit"
            />
          </div>
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
