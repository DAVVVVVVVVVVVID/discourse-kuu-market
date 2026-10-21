import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import routeAction from "discourse/helpers/route-action";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { gt } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { openDirectMessages } from "../../lib/kuu-market";

const VISIBLE_AVATARS = 8;

// 在售帖「举手购买」、求购帖「举手售出」，后面按举手顺序排出举手人的头像（Issue #5 第一期）。
// 只在进行中的帖子上出现（raised_hands 只有这时才有）；作者自己看不到按钮
export default class RaisedHands extends Component {
  @service currentUser;
  @service dialog;
  @service router;
  @service toasts;

  @tracked saving = false;

  get listing() {
    return this.args.listing;
  }

  get kind() {
    return this.listing.kind;
  }

  get hands() {
    return this.listing.raised_hands;
  }

  // 未登录的人也看到按钮，点了去登录
  get showRaiseButton() {
    return this.currentUser ? this.listing.can_raise_hand : true;
  }

  get visibleHands() {
    return this.hands.slice(0, VISIBLE_AVATARS);
  }

  get hiddenCount() {
    return this.hands.length - VISIBLE_AVATARS;
  }

  get raiseLabel() {
    return i18n(`kuu_market.hands.raise.${this.kind}`);
  }

  get countLabel() {
    return i18n(`kuu_market.hands.count.${this.kind}`, {
      count: this.hands.length,
    });
  }

  @action
  async raise() {
    await this.#save("raised", "POST");
  }

  @action
  cancel() {
    this.dialog.yesNoConfirm({
      message: i18n(`kuu_market.hands.confirm_cancel.${this.kind}`),
      didConfirm: () => this.#save("cancelled", "DELETE"),
    });
  }

  async #save(event, type) {
    this.saving = true;

    try {
      const result = await ajax(
        `/kuu-market/listings/${this.listing.topic_id}/hand.json`,
        { type }
      );
      this.args.onChange(result.listing);
      if (event === "raised") {
        this.#announceRaised(result);
      } else {
        this.#announceCancelled(result.delivery);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  // 举手后用居中的简单弹窗（Issue #9）：发出去了可以直接去和发帖人的对话；
  // 没发出去打不开私聊，只有「继续浏览」
  #announceRaised({ delivery, chat_channel_id }) {
    if (delivery === "sent") {
      this.dialog.confirm({
        class: "kuu-market-hand-dialog",
        message: i18n(`kuu_market.hands.sent.raised.${this.kind}`),
        confirmButtonLabel: "kuu_market.hands.open_chat",
        cancelButtonLabel: "kuu_market.hands.keep_browsing",
        didConfirm: () => openDirectMessages(this.router, chat_channel_id),
      });
    } else {
      this.dialog.alert({
        class: "kuu-market-hand-dialog",
        message: this.#undeliveredMessage("raised", delivery),
        confirmButtonLabel: "kuu_market.hands.keep_browsing",
      });
    }
  }

  // 取消举手照旧用角落的小提示
  #announceCancelled(delivery) {
    if (delivery === "sent") {
      this.toasts.success({
        duration: "long",
        data: { message: i18n(`kuu_market.hands.sent.cancelled.${this.kind}`) },
      });
    } else {
      this.toasts.warning({
        duration: "long",
        data: { message: this.#undeliveredMessage("cancelled", delivery) },
      });
    }
  }

  #undeliveredMessage(event, delivery) {
    return delivery === "poster_unavailable"
      ? i18n(`kuu_market.hands.poster_unavailable.${event}.${this.kind}`)
      : i18n(`kuu_market.hands.failed.${event}`);
  }

  <template>
    <div class="kuu-market-hands">
      {{#if this.listing.hand_raised}}
        <span class="kuu-market-hands__raised">
          {{dIcon "hand"}}
          {{i18n "kuu_market.hands.raised"}}
        </span>
        <DButton
          class="btn-default kuu-market-hands__cancel"
          @action={{this.cancel}}
          @disabled={{this.saving}}
          @isLoading={{this.saving}}
          @label="kuu_market.hands.cancel"
        />
      {{else if this.showRaiseButton}}
        <DButton
          class="btn-primary kuu-market-hands__raise"
          @action={{if this.currentUser this.raise (routeAction "showLogin")}}
          @disabled={{this.saving}}
          @icon="hand"
          @isLoading={{this.saving}}
          @translatedLabel={{this.raiseLabel}}
        />
      {{/if}}

      {{#if this.hands.length}}
        <div class="kuu-market-hands__queue">
          <span class="kuu-market-hands__avatars">
            {{#each this.visibleHands as |user|}}
              <a
                class="trigger-user-card kuu-market-hands__avatar"
                data-user-card={{user.username}}
                title={{user.username}}
              >
                {{dAvatar user imageSize="small"}}
              </a>
            {{/each}}
            {{#if (gt this.hiddenCount 0)}}
              <DMenu
                @identifier="kuu-market-hands"
                @triggerClass="btn-flat btn-small kuu-market-hands__more"
                @translatedLabel={{i18n
                  "kuu_market.hands.more"
                  count=this.hiddenCount
                }}
              >
                <:content>
                  <ul class="kuu-market-hands__list">
                    {{#each this.hands as |user|}}
                      <li>
                        <a
                          class="trigger-user-card"
                          data-user-card={{user.username}}
                        >
                          {{dAvatar user imageSize="small"}}
                          <span>{{user.username}}</span>
                        </a>
                      </li>
                    {{/each}}
                  </ul>
                </:content>
              </DMenu>
            {{/if}}
          </span>
          <span class="kuu-market-hands__count">
            {{this.countLabel}}
          </span>
        </div>
      {{/if}}
    </div>
  </template>
}
