import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import {
  LISTING_AREAS,
  LISTING_CATEGORIES,
  marketCategoryId,
} from "../../lib/kuu-market";

// 二手市场分类页顶部的两排筛选：校区、商品分类（Issue #11）。选中的值写在网址里（kuu_area / kuu_category），
// 刷新和分享链接都保持筛选。只在二手市场分类页出现，挂在主题「独立页面」顶栏下面、列表上面
export default class MarketFilters extends Component {
  @service router;
  @service siteSettings;

  get show() {
    const category = this.args.outletArgs.category;
    return !!category && category.id === marketCategoryId(this.siteSettings);
  }

  get rows() {
    const query = this.router.currentRoute?.queryParams ?? {};
    return [
      {
        param: "kuu_area",
        label: i18n("kuu_market.filters.area"),
        options: this.#options(query.kuu_area, LISTING_AREAS, "area_short"),
      },
      {
        param: "kuu_category",
        label: i18n("kuu_market.filters.category"),
        options: this.#options(
          query.kuu_category,
          LISTING_CATEGORIES,
          "categories"
        ),
      },
    ];
  }

  @action
  select(param, value) {
    this.router.transitionTo({ queryParams: { [param]: value } });
  }

  #options(current, keys, labelKey) {
    const selected = keys.includes(current) ? current : null;
    return [
      {
        value: null,
        label: i18n("kuu_market.filters.all"),
        isSelected: !selected,
      },
      ...keys.map((key) => ({
        value: key,
        label: i18n(`kuu_market.${labelKey}.${key}`),
        isSelected: key === selected,
      })),
    ];
  }

  <template>
    {{#if this.show}}
      <div class="kuu-market-filters">
        {{#each this.rows as |row|}}
          <div class="kuu-market-filters__row" data-param={{row.param}}>
            <span class="kuu-market-filters__label">{{row.label}}</span>
            <div class="kuu-market-filters__options">
              {{#each row.options as |option|}}
                <DButton
                  aria-pressed={{if option.isSelected "true" "false"}}
                  class="btn-flat kuu-market-filters__option
                    {{if option.isSelected '--selected'}}"
                  data-value={{if option.value option.value "all"}}
                  @action={{fn this.select row.param option.value}}
                  @translatedLabel={{option.label}}
                />
              {{/each}}
            </div>
          </div>
        {{/each}}
      </div>
    {{/if}}
  </template>
}
