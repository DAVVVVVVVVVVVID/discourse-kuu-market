import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { titleWithColoredPrefix } from "discourse/plugins/discourse-kuu-market/discourse/lib/kuu-market";

module("Unit | KUU market | titleWithColoredPrefix", function (hooks) {
  setupTest(hooks);

  test("wraps the generated prefix of a sell listing", function (assert) {
    assert.strictEqual(
      titleWithColoredPrefix("【出售】宜家书桌 · ¥3,000", "【出售】", "sell"),
      '<span class="kuu-market-title-prefix kuu-market-title-prefix--sell">【出售】</span>宜家书桌 · ¥3,000'
    );
  });

  test("colours buy listings differently", function (assert) {
    assert.true(
      titleWithColoredPrefix("【求购】自行车", "【求购】", "buy").includes(
        "kuu-market-title-prefix--buy"
      )
    );
  });

  test("compares against the escaped prefix", function (assert) {
    assert.strictEqual(
      titleWithColoredPrefix("&lt;Sale&gt; Desk", "<Sale> ", "sell"),
      '<span class="kuu-market-title-prefix kuu-market-title-prefix--sell">&lt;Sale&gt; </span>Desk'
    );
  });

  test("leaves titles that do not start with the prefix alone", function (assert) {
    assert.strictEqual(
      titleWithColoredPrefix("Desk renamed by staff", "【出售】", "sell"),
      "Desk renamed by staff"
    );
  });

  test("leaves topics without listing data alone", function (assert) {
    assert.strictEqual(
      titleWithColoredPrefix("【出售】Desk", undefined, undefined),
      "【出售】Desk"
    );
  });
});
