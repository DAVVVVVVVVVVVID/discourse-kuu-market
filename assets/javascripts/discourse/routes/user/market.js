import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

// 只有本人和管理员能看：别人打开时接口返回 404，显示 core 的「页面不存在」
export default class UserMarketRoute extends DiscourseRoute {
  model() {
    const username = this.modelFor("user").username;
    return ajax(`/kuu-market/users/${username}/listings.json`);
  }

  titleToken() {
    return i18n("kuu_market.my_listings.title");
  }
}
