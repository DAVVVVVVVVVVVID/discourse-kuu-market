import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import {
  LISTING_CATEGORIES,
  MAX_LISTING_CATEGORIES,
} from "../../lib/kuu-market";

// 表单里的商品分类：点一下选中，再点取消，最多选 MAX_LISTING_CATEGORIES 个（Issue #11）
export default class CategoryChips extends Component {
  get selected() {
    return this.args.value ?? [];
  }

  get full() {
    return this.selected.length >= MAX_LISTING_CATEGORIES;
  }

  get chips() {
    return LISTING_CATEGORIES.map((key) => {
      const isSelected = this.selected.includes(key);
      return {
        key,
        isSelected,
        disabled: !isSelected && this.full,
        label: i18n(`kuu_market.categories.${key}`),
      };
    });
  }

  @action
  toggle(key) {
    this.args.onChange(
      this.selected.includes(key)
        ? this.selected.filter((selected) => selected !== key)
        : [...this.selected, key]
    );
  }

  <template>
    <div class="kuu-market-chips" role="group">
      {{#each this.chips as |chip|}}
        <DButton
          aria-pressed={{if chip.isSelected "true" "false"}}
          class="btn-default kuu-market-chips__chip
            {{if chip.isSelected '--selected'}}"
          data-category={{chip.key}}
          @action={{fn this.toggle chip.key}}
          @disabled={{chip.disabled}}
          @translatedLabel={{chip.label}}
        />
      {{/each}}
    </div>
  </template>
}
