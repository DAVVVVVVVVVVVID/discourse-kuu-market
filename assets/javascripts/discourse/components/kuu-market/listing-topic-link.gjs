import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";
import { splitTitlePrefix, titlePrefixClass } from "../../lib/kuu-market";

// 包在 core 话题列表标题（topic-list/topic-link）外面：二手帖的标题开头单独上色，其余照 core 原样渲染。
// 不是二手帖、或者标题不以插件生成的前缀开头时，直接交回 core 的渲染（yield）。
// core 的两处调用都传了 raw-topic-link 类名和 focus / blur 处理，这里照抄，键盘浏览列表时的高亮才不会丢
export default class ListingTopicLink extends Component {
  get topic() {
    return this.args.outletArgs.topic;
  }

  get titleParts() {
    return splitTitlePrefix(
      this.topic.fancyTitle,
      this.topic.kuu_market_title_prefix
    );
  }

  get prefixClass() {
    return titlePrefixClass(this.topic.kuu_market_kind);
  }

  get url() {
    return this.topic.linked_post_number
      ? this.topic.urlForPostNumber(this.topic.linked_post_number)
      : this.topic.lastUnreadUrl;
  }

  @action
  highlightItem(event) {
    event.target.closest(".topic-list-item")?.classList.add("selected");
  }

  @action
  unhighlightItem(event) {
    event.target.closest(".topic-list-item")?.classList.remove("selected");
  }

  <template>
    {{~#if this.titleParts~}}
      <a
        class="title raw-link raw-topic-link"
        data-topic-id={{this.topic.id}}
        href={{this.url}}
        {{on "focus" this.highlightItem}}
        {{on "blur" this.unhighlightItem}}
      >
        {{~! no whitespace ~}}
        <span class={{this.prefixClass}}>{{this.titleParts.prefix}}</span>
        {{~trustHTML this.titleParts.rest~}}
        {{~#if this.topic.visited~}}
          <span class="sr-only">&nbsp;{{i18n "topic.sr_read"}}</span>
        {{~/if~}}
      </a>
    {{~else~}}
      {{yield}}
    {{~/if~}}
  </template>
}
