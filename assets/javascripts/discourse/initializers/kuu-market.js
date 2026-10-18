import CustomNotification from "discourse/lib/notification-types/custom";
import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import ListingPanel from "../components/kuu-market/listing-panel";
import ListingForm from "../components/kuu-market/modal/listing-form";
import { marketCategoryId, titleWithColoredPrefix } from "../lib/kuu-market";

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

      // 标题开头的【出售】【赠送】【求购】单独上色（2026-10-19 David 定）。只有带着插件数据的话题
      // （话题列表、帖子页）才改；搜索结果、推荐话题等地方的话题没有这些数据，保持纯文字
      api.modifyClass(
        "model:topic",
        (Superclass) =>
          class extends Superclass {
            get fancyTitle() {
              const listing = this.kuu_market_listing;
              return titleWithColoredPrefix(
                super.fancyTitle,
                this.kuu_market_title_prefix ?? listing?.title_prefix,
                this.kuu_market_kind ?? listing?.kind
              );
            }
          }
      );

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
