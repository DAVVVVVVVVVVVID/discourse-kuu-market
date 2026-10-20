import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { titlePrefixClass } from "discourse/plugins/discourse-kuu-market/discourse/lib/kuu-market";

module("Unit | KUU market | title prefix", function (hooks) {
  setupTest(hooks);

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
