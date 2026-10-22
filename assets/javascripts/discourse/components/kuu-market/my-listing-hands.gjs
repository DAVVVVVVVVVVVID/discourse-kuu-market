import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";
import HandChats from "./modal/hand-chats";

// 一行最多放几个头像，多的显示「+N」。手机上卡片窄，还要留出「+N」和「去私信」的位置
const VISIBLE_AVATARS = { desktop: 12, mobile: 5 };

// 「我的商品」卡片下面一行（Issue #15）：正在排队的举手人头像（按举手顺序，点开用户卡片），
// 最右边「去私信」打开只有这件商品举手人的私聊列表。只有进行中的帖子有这一行
export default class MyListingHands extends Component {
  @service modal;
  @service site;

  get hands() {
    return this.args.listing.raised_hands;
  }

  // 只有进行中的帖子带 raised_hands；排队为空时显示「还没有人举手」
  get hasQueue() {
    return Array.isArray(this.hands);
  }

  get visibleCount() {
    return this.site.mobileView
      ? VISIBLE_AVATARS.mobile
      : VISIBLE_AVATARS.desktop;
  }

  get visibleHands() {
    return this.hands.slice(0, this.visibleCount);
  }

  get hiddenCount() {
    return Math.max(this.hands.length - this.visibleCount, 0);
  }

  @action
  openChats() {
    this.modal.show(HandChats, { model: { listing: this.args.listing } });
  }

  <template>
    {{#if this.hasQueue}}
      <div class="kuu-market-my-listings__hands-row">
        {{#if this.hands.length}}
          <span class="kuu-market-my-listings__hands-label">
            {{i18n "kuu_market.hand_chats.label"}}
          </span>
          <span class="kuu-market-my-listings__avatars">
            {{#each this.visibleHands as |user|}}
              <a
                class="trigger-user-card kuu-market-my-listings__avatar"
                data-user-card={{user.username}}
                title={{user.username}}
              >
                {{dAvatar user imageSize="small"}}
              </a>
            {{/each}}
          </span>
          {{#if this.hiddenCount}}
            <span class="kuu-market-my-listings__more">
              +{{this.hiddenCount}}
            </span>
          {{/if}}
          <DButton
            class="btn-default kuu-market-my-listings__chats"
            @action={{this.openChats}}
            @icon="d-chat"
            @label="kuu_market.hands.open_chat"
          />
        {{else}}
          <span class="kuu-market-my-listings__no-hands">
            {{i18n "kuu_market.hand_chats.nobody"}}
          </span>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
