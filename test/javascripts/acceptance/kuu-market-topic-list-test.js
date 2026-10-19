import { focus, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("KUU market | topic list classes", function (needs) {
  needs.user();
  needs.settings({ kuu_market_enabled: true });
  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {
      const json = cloneJSON(DiscoveryFixtures["/latest.json"]);
      const [selling, sold, renamed] = json.topic_list.topics;
      Object.assign(selling, {
        fancy_title: "【出售】宜家书桌 · ¥3,000",
        kuu_market_kind: "sell",
        kuu_market_status: "selling",
        kuu_market_title_prefix: "【出售】",
      });
      Object.assign(sold, {
        fancy_title: "【求购】自行车",
        kuu_market_kind: "buy",
        kuu_market_status: "closed",
        kuu_market_title_prefix: "【求购】",
      });
      Object.assign(renamed, {
        fancy_title: "Desk renamed by staff",
        kuu_market_kind: "sell",
        kuu_market_status: "selling",
        kuu_market_title_prefix: "【出售】",
      });
      return helper.response(json);
    });
  });

  test("marks listings with their kind and status", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topic-list-item.kuu-market-listing")
      .exists({ count: 3 }, "only listings are marked");
    assert
      .dom(".topic-list-item.kuu-market-kind-sell.kuu-market-status-selling")
      .exists();
    assert
      .dom(".topic-list-item.kuu-market-kind-buy.kuu-market-status-closed")
      .exists();
  });

  test("colours the title prefix and keeps core's title link", async function (assert) {
    await visit("/latest");

    const sellLink = ".topic-list-item.kuu-market-kind-sell a.title";
    assert
      .dom(`${sellLink}.raw-topic-link .kuu-market-title-prefix--sell`)
      .hasText("【出售】");
    assert
      .dom(`${sellLink}.raw-topic-link`)
      .hasText("【出售】宜家书桌 · ¥3,000");
    assert
      .dom(
        ".topic-list-item.kuu-market-kind-buy a.title .kuu-market-title-prefix--buy"
      )
      .hasText("【求购】");
    assert
      .dom(".kuu-market-title-prefix")
      .exists({ count: 2 }, "a renamed listing and other topics stay plain");

    await focus(sellLink);
    assert
      .dom(".topic-list-item.kuu-market-kind-sell")
      .hasClass("selected", "keyboard focus still highlights the row");
  });

  test("leaves the topic model's title plain", function (assert) {
    const topic = this.owner.lookup("service:store").createRecord("topic", {
      id: 999,
      fancy_title: "【出售】宜家书桌",
      kuu_market_kind: "sell",
      kuu_market_title_prefix: "【出售】",
    });

    assert.strictEqual(
      topic.fancyTitle,
      "【出售】宜家书桌",
      "themes that use fancyTitle as image alt text get plain text"
    );
  });
});

acceptance("KUU market | topic list classes when disabled", function (needs) {
  needs.user();
  needs.settings({ kuu_market_enabled: false });
  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {
      const json = cloneJSON(DiscoveryFixtures["/latest.json"]);
      Object.assign(json.topic_list.topics[0], {
        fancy_title: "【出售】宜家书桌",
        kuu_market_kind: "sell",
        kuu_market_status: "selling",
        kuu_market_title_prefix: "【出售】",
      });
      return helper.response(json);
    });
  });

  test("adds no classes", async function (assert) {
    await visit("/latest");

    assert.dom(".kuu-market-listing").doesNotExist();
    assert.dom(".kuu-market-title-prefix").doesNotExist();
  });
});
