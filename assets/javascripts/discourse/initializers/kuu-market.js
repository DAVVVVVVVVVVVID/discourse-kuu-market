import { ajax } from "discourse/lib/ajax";
import CustomNotification from "discourse/lib/notification-types/custom";
import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import ListingPanel from "../components/kuu-market/listing-panel";
import ListingTopicLink from "../components/kuu-market/listing-topic-link";
import ListingForm from "../components/kuu-market/modal/listing-form";
import TopicTitlePrefix from "../components/kuu-market/topic-title-prefix";
import {
  handAlertMessage,
  marketCategoryId,
  openDirectMessages,
} from "../lib/kuu-market";

// 作者收到的「你的帖子过期了」和举手人收到的「举手的帖子过期了」
const EXPIRY_MESSAGES = {
  "kuu_market.notifications.expired": "expired",
  "kuu_market.notifications.hand_expired": "hand_expired",
};

export default {
  name: "kuu-market",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.kuu_market_enabled) {
      return;
    }

    const modal = container.lookup("service:modal");
    const dialog = container.lookup("service:dialog");
    const router = container.lookup("service:router");

    // 「新建话题」按钮由 discourse-kuu-new-topic 统一处理：在二手市场分类里直接打开表单，
    // 其他地方出现在选择框里（2026-10-19 David 定）。不管从哪里打开，帖子都发到二手市场分类。
    // 排在评分主题前面；在二手市场没有发帖权限的人看不到这一项
    container.lookup("service:kuu-new-topic")?.register({
      id: "kuu-market-listing",
      label: "kuu_market.new_topic.label",
      description: "kuu_market.new_topic.description",
      icon: "cart-shopping",
      categoryIds: () => [marketCategoryId(siteSettings)].filter(Boolean),
      inChooser: () =>
        !!Category.findById(marketCategoryId(siteSettings))?.canCreateTopic,
      order: -1,
      open: () => modal.show(ListingForm, { model: {} }),
    });

    withPluginApi((api) => {
      api.renderInOutlet("topic-above-posts", ListingPanel);

      // 有新的人举手时，发帖人打开论坛后弹窗提醒一次（Issue #5 第二期）。等第一个页面渲染好再弹；
      // 关掉以后告诉后端这批看过了，弹窗打开以后才举手的人下次再弹
      const currentUser = api.getCurrentUser();
      if (currentUser?.kuu_market_hand_alerts) {
        let shown = false;
        api.onPageChange(async () => {
          const alerts = currentUser.kuu_market_hand_alerts;
          if (shown || !alerts) {
            return;
          }
          shown = true;

          // 和「取消举手」确认框一样的居中弹窗（Issue #9）。「去私信」「继续浏览」、点外面关掉，
          // 都算看过这批
          await dialog.confirm({
            class: "kuu-market-hand-alert",
            message: handAlertMessage(alerts),
            confirmButtonLabel: "kuu_market.hands.open_chat",
            cancelButtonLabel: "kuu_market.hands.keep_browsing",
            didConfirm: () =>
              openDirectMessages(router, alerts.chat_channel_id),
          });
          currentUser.set("kuu_market_hand_alerts", null);
          await ajax("/kuu-market/hand-alerts/dismiss.json", {
            type: "PUT",
            data: { up_to_id: alerts.up_to_id },
          });
        });
      }

      // 标题开头的【出售】【赠送】【求购】单独上色（2026-10-19 David 定），只在列表标题和帖子页大标题。
      // 不改模型的 fancyTitle：别的地方（比如主题拿标题当图片 alt）要的是纯文字
      api.renderInOutlet("topic-link", ListingTopicLink);
      api.renderInOutlet("topic-title-suffix", TopicTitlePrefix);

      // 第一楼由表单生成，作者用「修改」按钮改；管理员保留普通编辑
      api.registerValueTransformer(
        "post-menu-buttons",
        ({ value: dag, context: { post, state } }) => {
          if (
            post.post_number === 1 &&
            post.topic?.kuu_market_listing &&
            !state.currentUser?.staff
          ) {
            dag.delete("edit");
          }
        }
      );

      api.registerValueTransformer(
        "topic-list-item-class",
        ({ value, context }) => {
          const { kuu_market_kind: kind, kuu_market_status: status } =
            context.topic;
          if (!kind) {
            return value;
          }

          return [
            ...value,
            "kuu-market-listing",
            `kuu-market-kind-${kind}`,
            `kuu-market-status-${status}`,
          ];
        }
      );

      // 只接管插件自己的过期通知，其他 custom 通知保持 core 原样
      api.registerNotificationTypeRenderer(
        "custom",
        () =>
          class extends CustomNotification {
            get #expiryKey() {
              return EXPIRY_MESSAGES[this.notification.data.message];
            }

            get icon() {
              return this.#expiryKey ? "clock-rotate-left" : super.icon;
            }

            get label() {
              return this.#expiryKey
                ? i18n(
                    `kuu_market.notifications.${this.#expiryKey}_${this.#kind}`
                  )
                : super.label;
            }

            get linkTitle() {
              return this.#expiryKey
                ? i18n(`kuu_market.notifications.${this.#expiryKey}_title`)
                : super.linkTitle;
            }

            get #kind() {
              return this.notification.data.kind === "buy" ? "buy" : "sell";
            }
          }
      );
    });
  },
};
