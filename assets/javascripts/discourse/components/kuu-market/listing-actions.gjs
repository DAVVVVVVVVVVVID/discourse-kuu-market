import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { longDate } from "discourse/lib/formatter";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import DealPicker from "./modal/deal-picker";
import ListingForm from "./modal/listing-form";

// 作者和管理员管理二手帖的按钮：切换状态（标记已出时照旧选成交对象）和「修改」。
// 帖子页和「我的商品」页共用（Issue #12），改完刷新当前页面
export default class ListingActions extends Component {
  @service dialog;
  @service modal;
  @service router;
  @service siteSettings;
  @service toasts;

  @tracked changingTo = null;

  get listing() {
    return this.args.listing;
  }

  get isChanging() {
    return !!this.changingTo;
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
    <div class="kuu-market-panel__actions" ...attributes>
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
      {{yield}}
    </div>
  </template>
}
