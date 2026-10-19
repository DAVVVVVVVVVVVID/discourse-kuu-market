import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  splitTitlePrefix,
  titlePrefixClass,
} from "discourse/plugins/discourse-kuu-market/discourse/lib/kuu-market";

module("Unit | KUU market | title prefix", function (hooks) {
  setupTest(hooks);

  test("splits the generated prefix off the title", function (assert) {
    assert.deepEqual(
      splitTitlePrefix("【出售】宜家书桌 · ¥3,000", "【出售】"),
      { prefix: "【出售】", rest: "宜家书桌 · ¥3,000" }
    );
  });

  test("compares against the escaped prefix", function (assert) {
    assert.deepEqual(splitTitlePrefix("&lt;Sale&gt; Desk", "<Sale> "), {
      prefix: "<Sale> ",
      rest: "Desk",
    });
  });

  test("leaves titles that do not start with the prefix alone", function (assert) {
    assert.strictEqual(
      splitTitlePrefix("Desk renamed by staff", "【出售】"),
      null
    );
    assert.strictEqual(splitTitlePrefix("【出售】Desk", undefined), null);
  });

  test("colours by kind only", function (assert) {
    assert.strictEqual(
      titlePrefixClass("sell"),
      "kuu-market-title-prefix kuu-market-title-prefix--sell"
    );
    assert.strictEqual(
      titlePrefixClass("buy"),
      "kuu-market-title-prefix kuu-market-title-prefix--buy"
    );
  });
});
