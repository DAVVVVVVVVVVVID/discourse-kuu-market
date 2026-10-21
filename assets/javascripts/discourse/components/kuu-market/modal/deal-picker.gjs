import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

const NONE = "none";

// 作者标记已出 / 已购买时，从举手的人里选成交对象（Issue #5 第三期）。有人举手时才弹出。
// 不预先选「无」：必须明确选一项，免得没细看就把举手的人全部打发掉
export default class DealPicker extends Component {
  get listing() {
    return this.args.model.listing;
  }

  get title() {
    return i18n(`kuu_market.panel.deal.title.${this.listing.kind}`);
  }

  get description() {
    return i18n(`kuu_market.panel.deal.description.${this.listing.kind}`);
  }

  get confirmLabel() {
    const status = this.listing.kind === "buy" ? "closed" : "sold";
    return `kuu_market.panel.change_to.${status}`;
  }

  @action
  confirm({ deal_user_id }) {
    this.args.closeModal();
    this.args.model.onConfirm(deal_user_id === NONE ? null : deal_user_id);
  }

  <template>
    <DModal
      class="kuu-market-deal-modal"
      @closeModal={{@closeModal}}
      @title={{this.title}}
    >
      <:body>
        <p class="kuu-market-deal-modal__description">{{this.description}}</p>
        <Form class="kuu-market-deal-form" @onSubmit={{this.confirm}} as |form|>
          <form.Field
            @format="full"
            @name="deal_user_id"
            @showTitle={{false}}
            @title={{i18n "kuu_market.panel.deal.partner"}}
            @type="radio-group"
            @validation="required"
            as |field|
          >
            <field.Control as |radioGroup|>
              {{#each this.listing.raised_hands as |user|}}
                <radioGroup.Radio @value={{user.id}} as |radio|>
                  <radio.Title>
                    <span class="kuu-market-deal-form__user">
                      {{dAvatar user imageSize="small"}}
                      {{user.username}}
                    </span>
                  </radio.Title>
                </radioGroup.Radio>
              {{/each}}
              <radioGroup.Radio @value={{NONE}} as |radio|>
                <radio.Title>{{i18n "kuu_market.panel.deal.none"}}</radio.Title>
              </radioGroup.Radio>
            </field.Control>
          </form.Field>

          <form.Actions>
            <form.Submit
              class="kuu-market-deal-form__confirm"
              @label={{this.confirmLabel}}
            />
            <DButton class="btn-flat" @action={{@closeModal}} @label="cancel" />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
