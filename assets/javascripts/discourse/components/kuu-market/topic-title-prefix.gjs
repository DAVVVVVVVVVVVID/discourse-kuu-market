import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import { titlePrefixClass } from "../../lib/kuu-market";

// 帖子页大标题外面 core 没有挂载点，标题由 core 直接渲染。这里在标题渲染后把开头的前缀拆进上色元素：
// 只缩短 core 那段标题文字、在它前面插入元素，不动 Ember 管理的节点，标题重新渲染时也不会错乱；
// 标题变化时（比如作者改了内容）重新处理。core 改了标题结构、找不到那段文字时，标题保持纯文字
export default class TopicTitlePrefix extends Component {
  decorateTitle = modifier((element, [prefix, kind]) => {
    const anchor = element.closest("h1")?.querySelector("a.fancy-title");
    if (!anchor || !prefix) {
      return;
    }

    const decorate = () => decoratePrefix(anchor, prefix, kind);
    decorate();

    const observer = new MutationObserver(decorate);
    observer.observe(anchor, {
      childList: true,
      characterData: true,
      subtree: true,
    });

    return () => {
      observer.disconnect();
      removeDecoration(anchor);
    };
  });

  get listing() {
    return this.args.outletArgs.model.kuu_market_listing;
  }

  <template>
    {{#if this.listing}}
      <span
        hidden
        {{this.decorateTitle this.listing.title_prefix this.listing.kind}}
      ></span>
    {{/if}}
  </template>
}

const MARKER = "kuuMarketTitlePrefix";

function decoratePrefix(anchor, prefix, kind) {
  const existing = decoration(anchor);
  const titleNode = firstTitleNode(anchor);

  // 已经处理过，而且 core 没有重新渲染标题：什么都不做（这也让观察者不会无限触发）
  if (
    existing &&
    existing.textNode === titleNode &&
    existing.element.textContent === prefix &&
    existing.element.className === titlePrefixClass(kind)
  ) {
    return;
  }

  removeDecoration(anchor);
  if (
    titleNode?.nodeType !== Node.TEXT_NODE ||
    !titleNode.data.startsWith(prefix)
  ) {
    return;
  }

  const element = document.createElement("span");
  element.className = titlePrefixClass(kind);
  element.textContent = prefix;
  element.dataset[MARKER] = "";
  anchor.insertBefore(element, titleNode);
  titleNode.data = titleNode.data.slice(prefix.length);
  decorations.set(anchor, { element, textNode: titleNode });
}

function removeDecoration(anchor) {
  const existing = decoration(anchor);
  if (!existing) {
    return;
  }

  existing.element.remove();
  if (existing.textNode.isConnected) {
    existing.textNode.data =
      existing.element.textContent + existing.textNode.data;
  }
  decorations.delete(anchor);
}

const decorations = new WeakMap();

function decoration(anchor) {
  const existing = decorations.get(anchor);
  return existing?.element.isConnected ? existing : null;
}

// core 模板在标题前面留了空白文字节点，跳过它和插件自己插入的元素
function firstTitleNode(anchor) {
  for (const node of anchor.childNodes) {
    if (node.nodeType === Node.TEXT_NODE && !node.data.trim()) {
      continue;
    }
    if (node.dataset && MARKER in node.dataset) {
      continue;
    }
    return node;
  }
}
