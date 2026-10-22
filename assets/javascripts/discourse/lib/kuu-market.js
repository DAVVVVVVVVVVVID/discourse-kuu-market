import { escapeExpression } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

// 和后端 DiscourseKuuMarket::Listing 的限制保持一致
export const ITEM_NAME_MAX_LENGTH = 40;
export const LOCATION_MAX_LENGTH = 40;
export const DESCRIPTION_MAX_LENGTH = 2000;
export const MAX_YEN = 100_000_000;
export const BUY_MAX_PHOTOS = 1;

export const TRADE_METHODS = ["pickup", "delivery", "negotiable"];

// 位置范围和商品分类（Issue #11），和后端 Listing::AREAS / CATEGORIES 一致
export const LISTING_AREAS = ["yoshida", "uji", "katsura", "other"];
export const LISTING_CATEGORIES = [
  "furniture_appliances",
  "electronics",
  "clothing",
  "transport_sports",
  "entertainment",
  "study",
  "other",
];
export const MAX_LISTING_CATEGORIES = 3;

// 发帖人的举手提醒：每个帖子一行，最后一句「快去私信查收吧~」。dialog 把 message 当 HTML 输出，
// 商品名是用户填的，要先转义
export function handAlertMessage({ listings }) {
  const lines = listings.map(({ kind, item_name, count }) =>
    i18n(`kuu_market.hand_alert.line.${kind}`, {
      count,
      item: escapeExpression(item_name),
    })
  );
  return [...lines, i18n("kuu_market.hand_alert.hint")].join("<br>");
}

// 「去私信」：知道是哪个对话就直接打开，不知道（几个人举手）就打开私聊列表。
// 电脑上 chat 默认在右下角的抽屉里打开，手机上全屏，都按 chat 自己的习惯
export function openDirectMessages(router, chatChannelId) {
  if (chatChannelId) {
    router.transitionTo("chat.channel", "-", chatChannelId);
  } else {
    router.transitionTo("chat.direct-messages");
  }
}

export function marketCategoryId(siteSettings) {
  return parseInt(siteSettings.kuu_market_category, 10) || null;
}

export function maxPhotos(kind, siteSettings) {
  return kind === "buy" ? BUY_MAX_PHOTOS : siteSettings.kuu_market_max_photos;
}

export function formDataFor(listing, siteSettings) {
  if (!listing) {
    return {
      kind: "sell",
      item_name: "",
      price: null,
      free: false,
      budget_min: null,
      budget_max: null,
      location: siteSettings.kuu_market_default_location ?? "",
      // 和交易地点默认的「吉田本校区」一致
      area: "yoshida",
      categories: [],
      trade_method: "pickup",
      description: "",
      photos: [],
    };
  }

  return {
    kind: listing.kind,
    item_name: listing.item_name,
    price: listing.price,
    free: listing.free,
    budget_min: listing.budget_min,
    budget_max: listing.budget_max,
    location: listing.location,
    // 上线前发的帖子没有这两项，修改时要补填
    area: listing.area ?? null,
    categories: listing.categories ?? [],
    trade_method: listing.trade_method ?? "pickup",
    description: listing.description,
    photos: listing.photos ?? [],
  };
}

export function payloadFrom(data) {
  const common = {
    kind: data.kind,
    item_name: data.item_name?.trim(),
    location: data.location?.trim(),
    area: data.area,
    categories: data.categories,
    description: data.description ?? "",
    upload_ids: data.photos.map((photo) => photo.id),
  };

  if (data.kind === "sell") {
    return {
      ...common,
      free: !!data.free,
      price: data.free ? null : data.price,
      trade_method: data.trade_method,
    };
  }

  return {
    ...common,
    budget_min: data.budget_min,
    budget_max: data.budget_max,
  };
}

// 标题开头【出售】【赠送】【求购】的上色元素用的类名。只跟类型走，不随状态变（2026-10-19 David 定）
export function titlePrefixClass(kind) {
  return `kuu-market-title-prefix kuu-market-title-prefix--${kind === "buy" ? "buy" : "sell"}`;
}
