import CustomNotification from "discourse/lib/notification-types/custom";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import ListingPanel from "../components/kuu-market/listing-panel";
import ListingForm from "../components/kuu-market/modal/listing-form";
import { marketCategoryId } from "../lib/kuu-market";

const EXPIRED_MESSAGE = "kuu_market.notifications.expired";

export default {
  name: "kuu-market",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.kuu_market_enabled) {
      return;
    }

    const modal = container.lookup("service:modal");

    // 「新建话题」按钮由 discourse-kuu-new-topic 统一处理：在二手市场分类里直接打开表单，
    // 不出现在其他地方的选择框里（2026-10-18 David 定）
    container.lookup("service:kuu-new-topic")?.register({
      id: "kuu-market-listing",
      label: "kuu_market.new_topic.label",
      description: "kuu_market.new_topic.description",
      icon: "cart-shopping",
      categoryIds: () => [marketCategoryId(siteSettings)].filter(Boolean),
      open: () => modal.show(ListingForm, { model: {} }),
    });

    withPluginApi((api) => {
      api.renderInOutlet("topic-above-posts", ListingPanel);

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
            get #isExpiry() {
              return this.notification.data.message === EXPIRED_MESSAGE;
            }

            get icon() {
              return this.#isExpiry ? "clock-rotate-left" : super.icon;
            }

            get label() {
              return this.#isExpiry
                ? i18n(`kuu_market.notifications.expired_${this.#kind}`)
                : super.label;
            }

            get linkTitle() {
              return this.#isExpiry
                ? i18n("kuu_market.notifications.expired_title")
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
