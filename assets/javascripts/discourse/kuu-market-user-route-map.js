// 「我的商品」页（Issue #12）：/u/用户名/market
export default {
  resource: "user",
  path: "users/:username",
  map() {
    this.route("market");
  },
};
