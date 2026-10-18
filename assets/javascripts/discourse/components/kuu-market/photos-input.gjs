import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import DButton from "discourse/ui-kit/d-button";
import DPickFilesButton from "discourse/ui-kit/d-pick-files-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";
import { i18n } from "discourse-i18n";

// 多张照片：上传、删除、设为封面（第一张做卡片封面）。值是 [{ id, url }]
export default class PhotosInput extends Component {
  @tracked photos = this.args.value ?? [];

  inputId = `kuu-market-photos-${dUniqueId()}`;
  uppyUpload = new UppyUpload(getOwner(this), {
    id: this.inputId,
    type: "composer",
    maxFiles: this.args.max,
    validateUploadedFilesOptions: { imagesOnly: true },
    uploadDone: (upload) => this.#add(upload),
  });

  get isFull() {
    return this.photos.length >= this.args.max;
  }

  get isUploading() {
    return this.uppyUpload.uploading || this.uppyUpload.processing;
  }

  // label 本身不能用键盘触发，照 core 的图片上传组件补上回车和空格
  @action
  openPickerWithKeyboard(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      document.getElementById(this.inputId)?.click();
    }
  }

  @action
  remove(photo) {
    this.#change(this.photos.filter((p) => p.id !== photo.id));
  }

  @action
  makeCover(photo) {
    this.#change([photo, ...this.photos.filter((p) => p.id !== photo.id)]);
  }

  #add(upload) {
    if (this.isFull) {
      return;
    }

    this.#change([...this.photos, { id: upload.id, url: upload.url }]);
  }

  #change(photos) {
    this.photos = photos;
    this.args.onChange(photos);
  }

  <template>
    <div class="kuu-market-photos">
      <ul class="kuu-market-photos__list">
        {{#each this.photos as |photo index|}}
          <li class="kuu-market-photos__item" data-upload-id={{photo.id}}>
            <img alt="" class="kuu-market-photos__image" src={{photo.url}} />
            {{#if index}}
              <DButton
                class="btn-transparent btn-small kuu-market-photos__cover"
                @action={{fn this.makeCover photo}}
                @label="kuu_market.form.make_cover"
              />
            {{else}}
              <span class="kuu-market-photos__cover-badge">
                {{i18n "kuu_market.form.cover"}}
              </span>
            {{/if}}
            <DButton
              class="btn-transparent btn-small kuu-market-photos__remove"
              @action={{fn this.remove photo}}
              @icon="xmark"
              @title="kuu_market.form.remove_photo"
            />
          </li>
        {{/each}}
      </ul>

      {{#unless this.isFull}}
        <label
          class="btn btn-default kuu-market-photos__add
            {{if this.isUploading 'disabled'}}"
          for={{this.inputId}}
          tabindex="0"
          {{on "keydown" this.openPickerWithKeyboard}}
        >
          {{dIcon "upload"}}
          <DPickFilesButton
            @acceptedFormatsOverride="image/*"
            @allowMultiple={{true}}
            @fileInputDisabled={{this.isUploading}}
            @fileInputId={{this.inputId}}
            @registerFileInput={{this.uppyUpload.setup}}
          />
          {{if
            this.isUploading
            (i18n "uploading")
            (i18n "kuu_market.form.add_photos")
          }}
        </label>
      {{/unless}}

      <p class="kuu-market-photos__hint">
        {{i18n "kuu_market.form.photos_hint" count=@max}}
      </p>
    </div>
  </template>
}
