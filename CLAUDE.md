# discourse-kuu-market（给 Claude Code）

## 这是什么
- 京大中文论坛（KUU，京都大学学生论坛，Discourse 自托管）的二手市场插件
- 技术方案（需求和设计都以它为准）：Notion「项目中心 › 项目文档 › 京大论坛｜二手市场插件技术方案」
  https://app.notion.com/p/3fd43ea2113c81d4a963d57598017ca9 。开发前先读这份方案；方案改了要同步更新 Notion，在改动处写上日期
- 参考实现：同一作者的评分插件 `~/discourse/plugins/discourse-kuu-ratings`（插件结构、测试写法、CI、「新建话题」打开自己的表单、`TopicQuery.add_custom_filter` 过滤列表）。京大邮箱插件 `~/discourse/plugins/discourse-kuu-kyoto-email` 也是同一套约定。**这两个插件都不要改**
- 线上部署不归本仓库管，由 KUU 运维那边负责：论坛的运维记录、待办、上线记录在另一个私有仓库（Windows 上的 `D:\PROJECT\KUU`，GitHub `kuu-forum`）。本仓库只负责写部署说明，由 David 转交
- 本仓库是**公开**的：不要提交任何密钥、敏感信息、用户数据

## 已确定的规则（不要自行改，要改先问 David）
1. 帖子分两种：**出售**（免费赠送也算出售，价格栏勾「免费赠送」）和**求购**。类型发帖后不能改
2. 状态：出售是 在售 / 已出 / 过期；求购是 求购 / 结束 / 过期
3. 作者本人和管理员随时可以改状态，**不受编辑时限限制**
   - 出售：在售 ↔ 已出；过期 → 在售或已出
   - 求购：求购 ↔ 结束；过期 → 求购或结束
   - **任何人都不能手动改成过期**
4. 已出、结束、过期的帖子：
   - 别人的话题列表和搜索里不显示，链接仍能打开
   - 作者本人在自己的「活动 → 话题」里能看到
   - 管理员在所有列表里都能看到，书签显示为灰色
5. 已出和结束的帖子**自动关闭回复**，改回进行中时自动打开。过期的帖子**不关闭回复**
6. 帖子进入在售或求购状态满 **30 天**，自动变成过期，并给作者发站内通知。从最近一次进入进行中状态开始算，别人的回复不重新计时
7. 重新上架（改回在售或求购）时，30 天重新计时，帖子顶回「最新」列表最上面。**每个帖子 7 天内最多顶一次**，超过这个频率时状态照样能改，只是不顶
8. 二手市场里「新建话题」打开插件自己的表单，表单里先选出售还是求购，字段见方案 2.6。普通编辑器不能在二手市场发帖，这一点要在后端拦截，管理员除外。回复照常用普通编辑器
9. 表单里不填标题，标题由插件生成，例如「【出售】宜家书桌 · ¥3,000」。第一楼正文也由插件按表单内容生成 Markdown
10. 作者随时可以用同一个表单修改内容，不受编辑时限限制。修改内容不顶帖，也不重新计算过期时间
11. 不是插件发的帖子（比如分类置顶的规则帖），插件一律不管
12. 过期只发站内通知，不发邮件
13. 清仓帖用出售表单正常填写，价格填最低价
14. 管理员可以用普通编辑器改第一楼，但表单内容是正文的唯一来源：作者下次用表单修改时，正文按表单重新生成
15. 已出、结束、过期的帖子，作者本人和管理员默认也搜不到（用的是 core 的隐藏话题）；作者个人主页上的话题数会相应变少。这两点 David 已接受

## 「新建话题」按钮
- 由插件 `discourse-kuu-new-topic`（`~/discourse/plugins/discourse-kuu-new-topic`）统一处理，本插件**不要**自己注册 `create-topic-button-click` / `can-create-topic-button` 转换器，只向它登记类型：在二手市场分类里直接打开表单，其他地方出现在选择框里（2026-10-19 David 改；之前是不进选择框），帖子一律发到二手市场分类
- 它是硬依赖：`about.json` 里声明了 CI 测试时一起安装；部署时要一起装
- 登记接口见它的 README

## 分工：卡片书签的样式不在插件里
- 列表卡片的布局来自第三方主题 FKB Pro。卡片上的书签样式由 KUU 那边写在「KUU 自定义组件」里，和「评分帖」书签放在一起
- 插件负责让卡片带上状态信息：**在话题列表项上加类名**（状态和类型），命名写进部署说明，KUU 那边照着写 CSS
- 帖子页上的状态显示、切换按钮和表单由插件负责，样式也写在插件里。颜色尽量用品牌色：藏青 `#0A2D56`、樱花粉 `#ED8690`、浅雾蓝 `#C0D1E4`、米白 `#FCF9F2`

## 开发环境
- 本仓库位于 WSL 的 `~/discourse/plugins/discourse-kuu-market`，Discourse 源码在 `~/discourse`（官方仓库，不要改）
- 在 `~/discourse` 下执行：
  - `d/boot_dev`：启动容器；`d/shutdown_dev`：停止容器（不开发时停掉，本机内存只有 7.8GB）
  - `d/dev`：启动开发服务器，打开 http://localhost:3000
  - `d/rspec plugins/discourse-kuu-market/spec`：跑本插件的测试
  - 加了数据库迁移后，先执行 `d/rake db:migrate`，再执行 `RAILS_ENV=test d/rake db:migrate`
  - lint 要在容器里跑：`d/exec bin/lint --fix <文件...>`，路径相对 `~/discourse`
  - `bin/lint --fix` 先跑 stree 再跑 rubocop，rubocop 自动改出的长行不会再被 stree 格式化，CI 的 `stree check` 会失败。看到 rubocop 有 `corrected` 时再跑一遍 `bin/lint --fix`；推送前可以照 CI 检查一次：`docker exec -u discourse -w /src/plugins/discourse-kuu-market discourse_dev bash -lc 'bundle exec stree check Gemfile $(git ls-files "*.rb")'`
  - 开发环境的邮件在 MailHog 里看：`d/mailhog`，http://localhost:8025
- `d/` 脚本都用 `docker exec -it`。没有终端时（比如后台运行）会报 `the input device is not a TTY`，这一步直接失败，脚本却显示成功。要用 `script -qec '命令' /dev/null` 包一层
- 开发服务器发现 `plugins/` 下有变化会自动重启。复制文件、改名改到一半时可能报错，改完再重启一次就好。三个 KUU 插件会同时加载
- 改了 `plugin.rb` 或 `lib/` 之后，开发服务器重载可能留下孤儿 worker 或丢掉 `after_initialize` 里注册的东西（评分插件那边见过）。现象怪异时重启 `d/dev`
- system spec 的 Playwright 浏览器缺失、样式缓存不更新等问题，处理方法见评分插件的 `CLAUDE.md`
- system spec 和 QUnit 都要前端构建：`d/dev` 开着时用它的 Rolldown；没开时 system spec 会报 `Frontend build error`（`frontend/discourse/dist/manifest/build.json` 里的进程已经不在）
- QUnit：容器里没装 Chrome，借用 Playwright 的 Chromium（做法见 `discourse-kuu-new-topic` 的 `CLAUDE.md`），`d/dev` 没开时加 `--standalone`。浏览器偶尔启动后 30 秒没进展而失败，加 `-e QUNIT_BROWSER_INACTIVITY_TIMEOUT=180` 重跑：
  ```bash
  docker exec -u discourse -w /src -e DISCOURSE_DISABLE_BROWSER_SANDBOX=1 -e QUNIT_BROWSER_INACTIVITY_TIMEOUT=180 discourse_dev bash -lc \
    'export PATH=/src/tmp/kuu-chrome-bin:$PATH; bin/qunit --standalone plugins/discourse-kuu-market/test/javascripts'
  ```
- 测试库只有一个：不要同时跑两组 rspec（会死锁）
- **内存**：WSL 只有约 4.9GB。`d/dev` 默认 3 个 Rails worker，加上 Rolldown（约 2GB），开起来就只剩几百 MB，再开浏览器（截图、system spec、QUnit）会被系统强杀（退出码 137），Rails 日志里出现 `can't alloc thread`。开发时用 1 个 worker 启动：`script -qec 'docker exec -it -u discourse -w /src -e UNICORN_WORKERS=1 discourse_dev bin/dev' /dev/null`，浏览器一次只开一个
- `plugin.rb` 的 `required_version` 保持 `2026.1.0`，**不要写当前版本号**：开发环境和线上都是 `2026.10.0-latest`，按版本比较规则它比 `2026.10.0` 低。写高了插件不会被激活，设置却照样加载，Rails 启动时报 `undefined method 'configurable?' for nil`
- 插件总开关是站点设置 `kuu_market_enabled`，默认关闭，开发环境要在后台打开

## 约定
- 插件名 `discourse-kuu-market`，Ruby 模块 `DiscourseKuuMarket`，接口挂在 `/kuu-market`，站点设置都以 `kuu_market_` 开头
- 代码标识符用英文；面向用户的文案放在 `config/locales/`（zh_CN 和 en 都要有）
- 跟着 Discourse 官方插件的写法走：前端用 Glimmer 组件（.gjs）和 plugin outlet，**不要改 core**
- 每个功能都要写测试：后端用 RSpec，表单、按钮这类前端交互用 system spec
- 提交信息用中文；推送前先跑测试
- **main 必须随时能上线**：线上 rebuild 直接 clone main 的最新代码。推送后 main 上的 GitHub CI 要全部通过；改了数据库的话 annotations_tests 也要过（跑一次 annotate）
- 部署到线上（改服务器 app.yml、rebuild）由 KUU 那边负责，必须先得到 David 的同意。部署说明里不要替 David 表态
- 规则相关的改动先问 David；纯技术细节自己定，写进 Notion 方案
- 用中文交流
