import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import {
  DESCRIPTION_MAX_LENGTH,
  formDataFor,
  ITEM_NAME_MAX_LENGTH,
  LISTING_AREAS,
  LOCATION_MAX_LENGTH,
  MAX_LISTING_CATEGORIES,
  MAX_YEN,
  maxPhotos,
  payloadFrom,
  TRADE_METHODS,
} from "../../../lib/kuu-market";
import CategoryChips from "../category-chips";
import PhotosInput from "../photos-input";

// 发帖和修改共用。@model.listing 有值时是修改：类型不能改，提交后刷新帖子页
export default class ListingForm extends Component {
  @service router;
  @service siteSettings;
  @service toasts;

  @tracked flash;
  @tracked isSubmitting = false;

  descriptionValidation = `length:0,${DESCRIPTION_MAX_LENGTH}`;
  formData = formDataFor(this.args.model.listing, this.siteSettings);
  itemNameValidation = `required:trim|length:1,${ITEM_NAME_MAX_LENGTH}`;
  locationValidation = `required:trim|length:1,${LOCATION_MAX_LENGTH}`;
  priceValidation = `required|integer|between:0,${MAX_YEN}`;
  areas = LISTING_AREAS;
  maxCategories = MAX_LISTING_CATEGORIES;
  tradeMethods = TRADE_METHODS;
  yenValidation = `integer|between:0,${MAX_YEN}`;

  #formApi;

  get isEditing() {
    return !!this.args.model.listing;
  }

  get title() {
    return this.isEditing
      ? i18n("kuu_market.form.edit_title")
      : i18n("kuu_market.form.new_title");
  }

  @action
  registerApi(api) {
    this.#formApi = api;
  }

  @action
  photoLimit(kind) {
    return maxPhotos(kind, this.siteSettings);
  }

  @action
  submitForm() {
    this.#formApi.submit();
  }

  @action
  validate(data, { addError }) {
    const required = (name, titleKey) =>
      addError(name, {
        title: i18n(titleKey),
        message: i18n("kuu_market.form.errors.required"),
      });

    if (data.kind === "sell") {
      if (data.photos.length === 0) {
        required("photos", "kuu_market.form.photos");
      }
    } else if (!data.budget_min && !data.budget_max) {
      addError("budget_max", {
        title: i18n("kuu_market.form.budget"),
        message: i18n("kuu_market.form.errors.budget_required"),
      });
    } else if (
      data.budget_min &&
      data.budget_max &&
      Number(data.budget_min) > Number(data.budget_max)
    ) {
      addError("budget_max", {
        title: i18n("kuu_market.form.budget_max"),
        message: i18n("kuu_market.form.errors.budget_order"),
      });
    }

    if (!data.categories?.length) {
      required("categories", "kuu_market.form.categories");
    } else if (data.categories.length > MAX_LISTING_CATEGORIES) {
      addError("categories", {
        title: i18n("kuu_market.form.categories"),
        message: i18n("kuu_market.form.errors.too_many_categories", {
          count: MAX_LISTING_CATEGORIES,
        }),
      });
    }

    if (data.photos.length > maxPhotos(data.kind, this.siteSettings)) {
      addError("photos", {
        title: i18n("kuu_market.form.photos"),
        message: i18n("kuu_market.form.errors.too_many_photos", {
          count: maxPhotos(data.kind, this.siteSettings),
        }),
      });
    }
  }

  @action
  async submit(data) {
    this.flash = null;
    this.isSubmitting = true;

    try {
      if (this.isEditing) {
        await this.#update(data);
      } else {
        await this.#create(data);
      }
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  async #create(data) {
    const result = await ajax("/kuu-market/listings.json", {
      type: "POST",
      contentType: "application/json",
      data: JSON.stringify(payloadFrom(data)),
    });

    this.args.closeModal();

    if (result.action === "enqueued") {
      this.toasts.success({
        data: { message: i18n("kuu_market.form.pending_approval") },
      });
    } else {
      DiscourseURL.routeTo(result.post.post_url);
    }
  }

  async #update(data) {
    await ajax(
      `/kuu-market/listings/${this.args.model.listing.topic_id}.json`,
      {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify(payloadFrom(data)),
      }
    );

    this.args.closeModal();
    this.router.refresh();
  }

  <template>
    <DModal
      class="kuu-market-form-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
      @title={{this.title}}
    >
      <:body>
        <Form
          class="kuu-market-form"
          @data={{this.formData}}
          @onRegisterApi={{this.registerApi}}
          @onSubmit={{this.submit}}
          @validate={{this.validate}}
          as |form data|
        >
          {{#unless this.isEditing}}
            <form.Field
              @format="full"
              @name="kind"
              @title={{i18n "kuu_market.form.kind"}}
              @type="radio-group"
              @validation="required"
              as |field|
            >
              <field.Control as |radioGroup|>
                <radioGroup.Radio @value="sell">
                  {{i18n "kuu_market.kinds.sell"}}
                </radioGroup.Radio>
                <radioGroup.Radio @value="buy">
                  {{i18n "kuu_market.kinds.buy"}}
                </radioGroup.Radio>
              </field.Control>
            </form.Field>
          {{/unless}}

          <form.Field
            @format="full"
            @name="item_name"
            @title={{i18n "kuu_market.form.item_name"}}
            @type="input"
            @validation={{this.itemNameValidation}}
            as |field|
          >
            <field.Control
              placeholder={{i18n "kuu_market.form.item_name_placeholder"}}
            />
          </form.Field>

          {{#if (eq data.kind "sell")}}
            <form.Field
              @name="free"
              @title={{i18n "kuu_market.form.free"}}
              @type="checkbox"
              as |field|
            >
              <field.Control />
            </form.Field>

            {{#unless data.free}}
              <form.Field
                @name="price"
                @title={{i18n "kuu_market.form.price"}}
                @type="input-number"
                @validation={{this.priceValidation}}
                as |field|
              >
                <field.Control @before="¥" />
              </form.Field>
            {{/unless}}
          {{else}}
            <form.InputGroup as |inputGroup|>
              <inputGroup.Field
                @name="budget_min"
                @title={{i18n "kuu_market.form.budget_min"}}
                @type="input-number"
                @validation={{this.yenValidation}}
                as |field|
              >
                <field.Control @before="¥" />
              </inputGroup.Field>
              <inputGroup.Field
                @name="budget_max"
                @title={{i18n "kuu_market.form.budget_max"}}
                @type="input-number"
                @validation={{this.yenValidation}}
                as |field|
              >
                <field.Control @before="¥" />
              </inputGroup.Field>
            </form.InputGroup>
          {{/if}}

          <form.Field
            @name="area"
            @title={{i18n "kuu_market.form.area"}}
            @type="radio-group"
            @validation="required"
            as |field|
          >
            <field.Control as |radioGroup|>
              {{#each this.areas as |area|}}
                <radioGroup.Radio @value={{area}}>
                  {{i18n (concat "kuu_market.areas." area)}}
                </radioGroup.Radio>
              {{/each}}
            </field.Control>
          </form.Field>

          <form.Field
            @name="location"
            @title={{i18n "kuu_market.form.location"}}
            @type="input"
            @validation={{this.locationValidation}}
            as |field|
          >
            <field.Control
              placeholder={{i18n "kuu_market.form.location_placeholder"}}
            />
          </form.Field>

          {{#if (eq data.kind "sell")}}
            <form.Field
              @name="trade_method"
              @title={{i18n "kuu_market.form.trade_method"}}
              @type="radio-group"
              @validation="required"
              as |field|
            >
              <field.Control as |radioGroup|>
                {{#each this.tradeMethods as |method|}}
                  <radioGroup.Radio @value={{method}}>
                    {{i18n (concat "kuu_market.trade_methods." method)}}
                  </radioGroup.Radio>
                {{/each}}
              </field.Control>
            </form.Field>
          {{/if}}

          <form.Field
            @format="full"
            @helpText={{i18n
              "kuu_market.form.categories_hint"
              count=this.maxCategories
            }}
            @name="categories"
            @showOptional={{false}}
            @title={{i18n "kuu_market.form.categories"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <CategoryChips @onChange={{field.set}} @value={{field.value}} />
            </field.Control>
          </form.Field>

          <form.Field
            @format="full"
            @helpText={{i18n "kuu_market.form.privacy_hint"}}
            @name="description"
            @title={{i18n "kuu_market.form.description"}}
            @type="textarea"
            @validation={{this.descriptionValidation}}
            as |field|
          >
            <field.Control @height={{120}} />
          </form.Field>

          <form.Field
            @format="full"
            @name="photos"
            @title={{if
              (eq data.kind "sell")
              (i18n "kuu_market.form.photos")
              (i18n "kuu_market.form.reference_photo")
            }}
            @type="custom"
            as |field|
          >
            <field.Control>
              <PhotosInput
                @max={{this.photoLimit data.kind}}
                @onChange={{field.set}}
                @value={{field.value}}
              />
            </field.Control>
          </form.Field>
        </Form>
      </:body>

      <:footer>
        <DButton
          class="btn-primary kuu-market-form-modal__submit"
          @action={{this.submitForm}}
          @isLoading={{this.isSubmitting}}
          @label={{if
            this.isEditing
            "kuu_market.form.save"
            "kuu_market.form.publish"
          }}
        />
        <DButton class="btn-flat" @action={{@closeModal}} @label="cancel" />
      </:footer>
    </DModal>
  </template>
}
