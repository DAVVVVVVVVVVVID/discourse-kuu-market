import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import ListingForm from "./modal/listing-form";

// 帖子页标题下方：作者和管理员看到「修改」按钮
export default class ListingPanel extends Component {
  @service modal;

  get listing() {
    return this.args.outletArgs.model.kuu_market_listing;
  }

  @action
  edit() {
    this.modal.show(ListingForm, { model: { listing: this.listing } });
  }

  <template>
    {{#if this.listing.can_manage}}
      <div class="kuu-market-panel">
        <div class="kuu-market-panel__actions">
          <DButton
            class="btn-default kuu-market-panel__edit"
            @action={{this.edit}}
            @icon="pencil"
            @label="kuu_market.panel.edit"
          />
        </div>
      </div>
    {{/if}}
  </template>
}
