import { focus, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const PLACEHOLDER = "/images/kuu-placeholder.png";
const BUY_IMAGE = "/images/kuu-buy.png";

function listing(topic, kind, status, card) {
  return Object.assign(topic, {
    kuu_market_kind: kind,
    kuu_market_status: status,
    kuu_market_card: { free: false, has_photos: true, ...card },
  });
}

acceptance("KUU market | listing cards in topic lists", function (needs) {
  needs.user();
  needs.settings({
    kuu_market_enabled: true,
    kuu_market_placeholder_image: PLACEHOLDER,
    kuu_market_buy_image: BUY_IMAGE,
  });
  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {
      const json = cloneJSON(DiscoveryFixtures["/latest.json"]);
      const [withPhoto, withoutPhoto, free, buy, sold, expired] =
        json.topic_list.topics;
      listing(withPhoto, "sell", "selling", {
        item_name: "MacBook Air M2",
        price: "¥52,000",
      }).image_url = "/images/macbook.jpg";
      listing(withoutPhoto, "sell", "selling", {
        item_name: "宜家书桌",
        price: "¥3,000",
        has_photos: false,
      });
      listing(free, "sell", "selling", {
        item_name: "电饭锅",
        price: "赠送",
        free: true,
      });
      listing(buy, "buy", "buying", {
        item_name: "自行车",
        price: "¥0–2,000",
        has_photos: true,
      }).image_url = "/images/reference.jpg";
      listing(sold, "sell", "sold", { item_name: "椅子", price: "¥500" });
      listing(expired, "buy", "expired", {
        item_name: "台灯",
        price: "¥1,000 以内",
      });
      return helper.response(json);
    });
  });

  function card(index) {
    return `.topic-list-item:nth-child(${index}) .kuu-market-card`;
  }

  test("shows a product card for each listing", async function (assert) {
    await visit("/latest");

    assert.dom(".kuu-market-card").exists({ count: 6 }, "only listings");
    assert
      .dom(
        ".topic-list-item.kuu-market-listing.kuu-market-kind-buy.kuu-market-status-buying"
      )
      .exists("items keep the kind and status classes for theme components");

    assert.dom(`${card(1)} .kuu-market-card__name`).hasText("MacBook Air M2");
    assert.dom(`${card(1)} .kuu-market-card__price`).hasText("¥52,000");
    assert
      .dom(`${card(1)} .kuu-market-card__image img`)
      .hasAttribute(
        "src",
        "/images/macbook.jpg",
        "sell listings use their photo"
      );
    assert
      .dom(`${card(1)} .kuu-market-card__status.kuu-market-status-selling`)
      .exists();

    assert
      .dom(`${card(2)} .kuu-market-card__image img`)
      .hasAttribute("src", PLACEHOLDER, "no photo: the placeholder");

    assert.dom(`${card(3)} .kuu-market-card__price.--free`).hasText("赠送");

    assert
      .dom(`${card(4)} .kuu-market-card__image img`)
      .hasAttribute("src", BUY_IMAGE, "buy listings always use the buy image");
    assert.dom(`${card(4)} .kuu-market-card__price`).hasText("¥0–2,000");
    assert
      .dom(`${card(4)} .kuu-market-card__status`)
      .hasText(i18n("kuu_market.card_statuses.buying"));

    assert
      .dom(card(5))
      .doesNotHaveClass("--expired", "sold listings are not faded");
    assert.dom(card(6)).hasClass("--expired", "expired listings are faded");
  });

  test("keeps core's title link behaviour", async function (assert) {
    await visit("/latest");

    assert.dom(card(1)).hasClass("raw-topic-link");
    assert.dom(card(1)).hasClass("title");

    await focus(card(1));
    assert
      .dom(".topic-list-item:nth-child(1)")
      .hasClass("selected", "keyboard focus still highlights the row");
  });

  test("leaves other topics alone", async function (assert) {
    await visit("/latest");

    assert
      .dom(".topic-list-item:nth-child(7) a.title.raw-topic-link")
      .exists("ordinary topics keep core's title link");
    assert.dom(".topic-list-item:nth-child(7) .kuu-market-card").doesNotExist();
  });

  test("leaves the topic model's title plain", function (assert) {
    const topic = this.owner.lookup("service:store").createRecord("topic", {
      id: 999,
      fancy_title: "【出售】宜家书桌",
      kuu_market_kind: "sell",
    });

    assert.strictEqual(
      topic.fancyTitle,
      "【出售】宜家书桌",
      "themes that use fancyTitle as image alt text get plain text"
    );
  });
});

acceptance("KUU market | listing cards when disabled", function (needs) {
  needs.user();
  needs.settings({ kuu_market_enabled: false });
  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {
      const json = cloneJSON(DiscoveryFixtures["/latest.json"]);
      listing(json.topic_list.topics[0], "sell", "selling", {
        item_name: "宜家书桌",
        price: "¥3,000",
      });
      return helper.response(json);
    });
  });

  test("shows plain topic list items", async function (assert) {
    await visit("/latest");

    assert.dom(".kuu-market-listing").doesNotExist();
    assert.dom(".kuu-market-card").doesNotExist();
  });
});
