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

// 标题开头【出售】【赠送】【求购】的上色元素用的类名。只跟类型走，不随状态变（2026-10-19 David 定）
export function titlePrefixClass(kind) {
  return `kuu-market-title-prefix kuu-market-title-prefix--${kind === "buy" ? "buy" : "sell"}`;
}
