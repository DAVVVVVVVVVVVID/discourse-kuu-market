import { test } from "qunit";
import Notification from "discourse/models/notification";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

function customNotification(data) {
  return Notification.create({
    id: 1,
    user_id: 1,
    notification_type: NOTIFICATION_TYPES.custom,
    read: false,
    post_number: 1,
    topic_id: 42,
    fancy_title: "【出售】宜家书桌 · ¥3,000",
    slug: "topic",
    data,
  });
}

acceptance("KUU market | expired notification", function (needs) {
  needs.user();
  needs.settings({ kuu_market_enabled: true });

  test("tells a seller their listing expired", function (assert) {
    const director = createRenderDirector(
      customNotification({
        message: "kuu_market.notifications.expired",
        kind: "sell",
      }),
      "custom",
      this.siteSettings
    );

    assert.strictEqual(
      director.label,
      i18n("kuu_market.notifications.expired_sell")
    );
    assert.strictEqual(
      director.linkTitle,
      i18n("kuu_market.notifications.expired_title")
    );
    assert.strictEqual(director.icon, "clock-rotate-left");
    assert.strictEqual(director.linkHref, "/t/topic/42");
  });

  test("tells a buyer their request expired", function (assert) {
    const director = createRenderDirector(
      customNotification({
        message: "kuu_market.notifications.expired",
        kind: "buy",
      }),
      "custom",
      this.siteSettings
    );

    assert.strictEqual(
      director.label,
      i18n("kuu_market.notifications.expired_buy")
    );
  });

  test("leaves other custom notifications alone", function (assert) {
    const director = createRenderDirector(
      customNotification({
        message: "some_plugin.notification",
        display_username: "someone",
      }),
      "custom",
      this.siteSettings
    );

    assert.strictEqual(director.label, "someone");
    assert.strictEqual(director.icon, "notification.some_plugin.notification");
  });
});
