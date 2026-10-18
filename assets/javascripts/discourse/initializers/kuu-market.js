import { withPluginApi } from "discourse/lib/plugin-api";

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
    });
  },
};
