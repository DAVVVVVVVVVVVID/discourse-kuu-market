import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { relativeAge } from "discourse/lib/formatter";
import { eq } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";
import { openDirectMessages } from "../../../lib/kuu-market";

// 「我的商品」页的「去私信」（Issue #15）：只有这件商品正在排队的举手人，按举手顺序。
// 点一行打开和他的私聊；还没有私聊频道的，照常新建（打不开时 chat 会提示原因）
export default class HandChats extends Component {
  @service chat;
  @service router;

  @tracked hands = null;

  constructor() {
    super(...arguments);
    this.#load();
  }

  get listing() {
    return this.args.model.listing;
  }

  get title() {
    return i18n(`kuu_market.hand_chats.title.${this.listing.kind}`, {
      item: this.listing.item_name,
    });
  }

  get rows() {
    return (this.hands ?? []).map((hand) => ({
      hand,
      raisedAgo: i18n("kuu_market.hand_chats.raised_at", {
        time: relativeAge(new Date(hand.raised_at), { addAgo: true }),
      }),
      preview: this.#preview(hand.last_message),
      hasUnread: hand.unread_count > 0,
    }));
  }

  @action
  async open(hand) {
    this.args.closeModal();

    if (hand.chat_channel_id) {
      openDirectMessages(this.router, hand.chat_channel_id);
      return;
    }

    const channel = await this.chat.upsertDmChannel({
      usernames: [hand.user.username],
    });
    if (channel) {
      this.router.transitionTo("chat.channel", ...channel.routeModels);
    }
  }

  async #load() {
    try {
      const result = await ajax(
        `/kuu-market/listings/${this.listing.topic_id}/hand-chats.json`
      );
      this.hands = result.hands;
    } catch (error) {
      this.hands = [];
      popupAjaxError(error);
    }
  }

  #preview(lastMessage) {
    if (!lastMessage) {
      return i18n("kuu_market.hand_chats.no_messages");
    }
    return lastMessage.mine
      ? i18n("kuu_market.hand_chats.mine", { excerpt: lastMessage.excerpt })
      : lastMessage.excerpt;
  }

  <template>
    <DModal
      class="kuu-market-hand-chats"
      @closeModal={{@closeModal}}
      @title={{this.title}}
    >
      <:body>
        <DConditionalLoadingSpinner @condition={{eq this.hands null}}>
          <ul class="kuu-market-hand-chats__list">
            {{#each this.rows as |row|}}
              <li>
                <button
                  class="kuu-market-hand-chats__row
                    {{if row.hasUnread '--unread'}}"
                  data-username={{row.hand.user.username}}
                  type="button"
                  {{on "click" (fn this.open row.hand)}}
                >
                  {{dAvatar row.hand.user imageSize="medium"}}
                  <span class="kuu-market-hand-chats__text">
                    <span class="kuu-market-hand-chats__head">
                      <span
                        class="kuu-market-hand-chats__name"
                      >{{row.hand.user.username}}</span>
                      <span
                        class="kuu-market-hand-chats__time"
                      >{{row.raisedAgo}}</span>
                    </span>
                    <span
                      class="kuu-market-hand-chats__preview"
                    >{{row.preview}}</span>
                  </span>
                  {{#if row.hasUnread}}
                    <span
                      class="kuu-market-hand-chats__unread"
                      title={{i18n "kuu_market.hand_chats.unread"}}
                    >{{row.hand.unread_count}}</span>
                  {{/if}}
                </button>
              </li>
            {{/each}}
          </ul>
        </DConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
