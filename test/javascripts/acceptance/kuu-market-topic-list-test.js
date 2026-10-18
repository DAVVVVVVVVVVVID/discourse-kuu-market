import { visit } from "@ember/test-helpers";
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
      const [selling, sold] = json.topic_list.topics;
      Object.assign(selling, {
        kuu_market_kind: "sell",
        kuu_market_status: "selling",
      });
      Object.assign(sold, {
        kuu_market_kind: "buy",
        kuu_market_status: "closed",
      });
      return helper.response(json);
    });
  });

  test("marks listings with their kind and status", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topic-list-item.kuu-market-listing")
      .exists({ count: 2 }, "only listings are marked");
    assert
      .dom(".topic-list-item.kuu-market-kind-sell.kuu-market-status-selling")
      .exists();
    assert
      .dom(".topic-list-item.kuu-market-kind-buy.kuu-market-status-closed")
      .exists();
  });
});

acceptance("KUU market | topic list classes when disabled", function (needs) {
  needs.user();
  needs.settings({ kuu_market_enabled: false });
  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {
      const json = cloneJSON(DiscoveryFixtures["/latest.json"]);
      Object.assign(json.topic_list.topics[0], {
        kuu_market_kind: "sell",
        kuu_market_status: "selling",
      });
      return helper.response(json);
    });
  });

  test("adds no classes", async function (assert) {
    await visit("/latest");

    assert.dom(".kuu-market-listing").doesNotExist();
  });
});
