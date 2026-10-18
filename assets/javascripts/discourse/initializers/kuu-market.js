import CustomNotification from "discourse/lib/notification-types/custom";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

const EXPIRED_MESSAGE = "kuu_market.notifications.expired";

export default {
  name: "kuu-market",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.kuu_market_enabled) {
      return;
    }

    withPluginApi((api) => {
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
