import { escapeExpression } from "discourse/lib/utilities";

// 和后端 DiscourseKuuMarket::Listing 的限制保持一致
export const ITEM_NAME_MAX_LENGTH = 40;
export const LOCATION_MAX_LENGTH = 40;
export const DESCRIPTION_MAX_LENGTH = 2000;
export const MAX_YEN = 100_000_000;
export const BUY_MAX_PHOTOS = 1;

export const TRADE_METHODS = ["pickup", "delivery", "negotiable"];

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

// fancyHtml 是 core 转义过的标题 HTML。标题确实以插件生成的前缀开头时，把前缀包成单独上色的元素；
// 不是的话（比如管理员手动改过标题）原样返回
export function titleWithColoredPrefix(fancyHtml, prefix, kind) {
  if (!fancyHtml || !prefix || !kind) {
    return fancyHtml;
  }

  const escapedPrefix = escapeExpression(prefix);
  if (!fancyHtml.startsWith(escapedPrefix)) {
    return fancyHtml;
  }

  const kindClass = kind === "buy" ? "buy" : "sell";
  return `<span class="kuu-market-title-prefix kuu-market-title-prefix--${kindClass}">${escapedPrefix}</span>${fancyHtml.slice(escapedPrefix.length)}`;
}
