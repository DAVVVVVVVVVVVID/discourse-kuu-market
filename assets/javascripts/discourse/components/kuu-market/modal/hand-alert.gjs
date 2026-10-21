import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

// 有新的人举手时，发帖人打开论坛看到的提醒（Issue #5 第二期）。几个帖子合在一个弹窗里
export default class HandAlert extends Component {
  @service router;

  get lines() {
    return this.args.model.listings.map(({ kind, item_name, count }) =>
      i18n(`kuu_market.hand_alert.line.${kind}`, { count, item: item_name })
    );
  }

  @action
  openChat() {
    this.args.closeModal();
    this.router.transitionTo("chat.direct-messages");
  }

  <template>
    <DModal
      class="kuu-market-hand-alert"
      @closeModal={{@closeModal}}
      @title={{i18n "kuu_market.hand_alert.title"}}
    >
      <:body>
        <ul class="kuu-market-hand-alert__lines">
          {{#each this.lines as |line|}}
            <li>{{line}}</li>
          {{/each}}
        </ul>
        <p class="kuu-market-hand-alert__hint">
          {{i18n "kuu_market.hand_alert.hint"}}
        </p>
      </:body>

      <:footer>
        <DButton
          class="btn-primary kuu-market-hand-alert__open-chat"
          @action={{this.openChat}}
          @icon="d-chat"
          @label="kuu_market.hand_alert.open_chat"
        />
        <DButton
          class="btn-flat kuu-market-hand-alert__close"
          @action={{@closeModal}}
          @label="kuu_market.hand_alert.close"
        />
      </:footer>
    </DModal>
  </template>
}
