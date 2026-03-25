# Grace Notes UI 改版方案

日期：2026-03-25

**状态：** 本文档仅包含设计与实施方案，不包含实际 UI 改动。

---

## 目标

让 Grace Notes 不再像一个套了暖色主题的文档编辑器，而更像一个安静、有辨识度、拥有自身视觉语言的每日反思产品。

目标不是“更花哨”，而是：

- 更有品牌识别度
- 更有设计意图
- 更精致
- 同时依然保持平静、温暖、情绪安全

本方案遵循 `.impeccable.md` 中已经确认的设计上下文：

- calm, warm, supportive
- light-mode-first
- paper-like, readable, low-pressure
- not gamified
- not dashboard-like
- not noisy or performative

---

## 核心问题

Grace Notes 现在已经有一套一致的主题，但这套主题主要体现在颜色和字体上，还没有真正体现在页面结构和交互层次上。

目前这款 app 给人的感觉更像：

- 一个用了自定义配色的标准 iOS 壳子
- 一组分段卡片和 section
- 一个带输入字段的 journaling 表单

而不是：

- 一个有节奏的每日仪式
- 一个陪伴式的反思工具
- 一个有明确视觉立场的产品

### 需要保留的现有优点

- `DesignSystem/Theme.swift` 中的 warm paper 配色
- 以衬线字体为主导的阅读气质
- `Soil`、`Seed`、`Ripening`、`Harvest`、`Abundance` 这一套成长模型
- 克制、平静的反馈和动效
- 低压力的交互方式

### 造成 “document 感” 的主要原因

1. app 壳层仍然过度依赖默认 iOS affordance。
2. 太多界面都在使用同一种圆角卡片 + 浅边框处理。
3. Today 页更像整齐的表单，而不是有仪式感的书写流程。
4. Review 更像带控件和列表的功能页，而不是每周摘要。
5. 视觉层级虽然统一，但过于平均，太多元素在用同样的音量说话。

---

## 北极星方向

这次改版建议把产品整体推进到一个更明确的方向：

**Quiet editorial ritual**

也就是：

- 更偏 editorial，而不是 utilitarian
- 更有纸张和手帐的触感，而不是强调 app chrome
- 更像被引导进入一个过程，而不是填写一个表单
- 让人记住的是整体构图和隐喻，而不是装饰细节

### 标志性概念

把“成长路径”变成 app 的标志性视觉语言。

`Soil -> Seed -> Ripening -> Harvest -> Abundance` 是产品里最有辨识度、也最值得放大的概念。它不应该只出现在一个 badge 或 pill 文案里，而应该进一步影响：

- 页面层级
- section 强弱关系
- 进度提示方式
- onboarding 结构
- review 的 framing
- 一些轻微但有记忆点的动画时刻

用户应该感受到自己是在一个温和的成长路径里前进，而不是在完成一个模板。

---

## 改版设计原则

## 1. 用“仪式感”替代表单感

用户进入 Today 时，应该感觉自己被邀请进入一个每日时刻，而不是面对一个空白生产力表单。

对应影响：

- Today 顶部需要更强的“进入感”
- 减少大量边框容器彼此竞争注意力
- 更明确地突出“下一步最有意义的动作”

## 2. 用“成长路径”替代通用进度 UI

完成度系统应该是 reflective、organic 的，而不是 gamified 的。

对应影响：

- 保留现在这套命名
- 避免 trophy、打卡、连续 streak 的视觉暗示
- 把 progression 当作方向引导，而不是施压

## 3. 用“编辑式摘要”替代控件感很强的 Review

Review 应该像一段每周阅读体验，而不是一个切 tab 看列表的功能界面。

对应影响：

- 更强的 hero insight
- 更清晰的叙事结构
- timeline 作为次级内容，而不是和 insight 平权

## 4. 让 app 壳子更像产品，而不是默认系统 UI

用户应该在第一眼就感觉“这是被设计过的”。

对应影响：

- tab identity 要更有意图
- 标题处理要更有产品感
- 降低对暗示“文档”或“工具”的 stock symbol 的依赖

## 5. 用“表面层级”替代“表面重复”

不是所有内容都应该被装进同一种圆角矩形里。

对应影响：

- 把有边框的 paper surface 优先保留给输入区域和关键 panel
- 引导文案、摘要、辅助说明尽量在合适场景下脱离卡片
- 通过更丰富的留白和容器关系建立节奏

---

## 建议的视觉语言

## 1. 壳层

### 目标气质

整体壳层应该是柔和、有设计意图的，而不是纯粹系统默认。

### 调整方向

- 重新看 `Application/GraceNotesApp.swift` 中的 tab icon，尤其是 `Today`
- 避免直接暗示文件、文档、工具的 icon
- 让 tab label 更像产品目的地，而不是功能桶
- 提高页面背景和 navigation/tab chrome 的区分度
- 给 Today 和 Review 这种主页面更有存在感的标题处理

### 建议

短期：

- 把 Today 上的 `doc.text` 换成更接近当下、反思、每日状态的 symbol，而不是文档
- 继续保留原生 `TabView`，但优化它的语义和配套视觉

中长期：

- 如果标准 tab bar 依然让 app 看起来太 generic，可以考虑做轻量级定制

---

## 2. Surface

### 当前问题

现在 app 在很多地方都重复同一种 paper card 处理，包括：

- onboarding
- suggestions
- tutorial hints
- Today 各 section
- Review panels
- settings sections

### 新的层级建议

定义三种不同职责的 surface：


| Surface 角色        | 适用内容                      | 视觉处理                   |
| ----------------- | ------------------------- | ---------------------- |
| **Canvas**        | 页面背景、开放式阅读区域              | 温暖、轻微着色背景，几乎没有边框       |
| **Paper**         | 重要叙事内容和摘要                 | 柔和底色、细微边缘、可选轻纹理、更大的留白  |
| **Input surface** | 文本输入、编辑器、可编辑 chips、toggle | 更明确的边框、更强的可操作感、最有触感的处理 |


### 规则

如果一个视图不是直接可编辑的，就不应该默认长得和输入区域一样。

---

## 3. 排版

### 当前问题

现有字体方向是对的，但不同角色之间的对比还不够强。

### 建议的体系

- 衬线字体继续承担 reflection、意义感、叙述感
- 无衬线字体继续承担控件、工具、元信息、导航

### 建议的角色分配


| 角色                    | 建议方向                      |
| --------------------- | ------------------------- |
| 页面关键时刻与反思性表达          | serif                     |
| Today 的 section 标题    | serif，但更融入页面空间，而不是卡片标题    |
| 导航、tab、控件、settings 标签 | sans                      |
| 日期、元信息、辅助标签           | 更安静的 sans，或视场景使用更小的 serif |


### 实际效果

Today 和 Review 应该更像“可读、可进入”的页面，而 Settings 继续保持操作性和清晰度。

---

## 4. 颜色与纹理

### 保留

- 温暖的 cream 背景
- terracotta accent
- muted 文本
- 柔和的绿色 / 暖色 progression 状态

### 增加

- 页面 canvas 和可编辑 surface 之间更明显的分离
- completion 各等级更有层次但仍克制的色阶
- 在大面积背景或关键 paper surface 上加入极轻的 texture / grain

### 避免

- 高对比渐变
- 过度发光、油亮的风格
- dark-mode-first 的戏剧化表达
- 饱和度过高的 success 颜色

纹理应该是“被感受到”，而不是“被注意到”。

---

## 5. 动效

### 保留

- 短、平静的过渡
- completion 反馈像温和确认
- 完整尊重 reduce motion

### 增加

- 关键页面的分阶段进入
- 开始编辑时 section emphasis 的轻微变化
- contextual guidance 和 review 摘要更柔和的显现方式

### 避免

- 过于弹跳、俏皮的 easing
- 几乎每次点击都来一段装饰性动画
- 任何会让产品显得像 reward loop 的动效

动效应该服务于 ritual 和 focus，而不是 novelty。

---

## 分页面改版方案

## 1. Today

**主要涉及文件：**

- `Features/Journal/Views/JournalScreen.swift`
- `Features/Journal/Views/DateSectionView.swift`
- `Features/Journal/Views/SequentialSectionView.swift`
- `Features/Journal/Views/EditableTextSection.swift`
- `Features/Journal/Views/JournalCompletionPill.swift`

### 当前观感

Today 现在是平静且可用的，但结构上更像：

- date/status block
- suggestion cards
- 三个重复的 chip-input section
- 两个重复的 text section

它很清晰，但确实更像一组表单模块。

### 目标观感

Today 应该更像进入一页“今日反思”，而且其中存在一个当前最活跃的书写流程。

### 建议层级

#### A. Ritual header

把页面顶部做成一个真正有存在感的时刻：

- 日期作为安静锚点
- completion state 作为品牌化的成长标记
- 一句短小但有气质的 contextual tone / framing
- 让用户明显感到自己“到达了某个每日时刻”

`DateSectionView.swift` 和 `JournalCompletionPill.swift` 已经有这个方向的雏形，可以把它们做成 app 最有辨识度的顶部区域。

#### B. Active writing stage

不要再让所有 section 都像平权模块那样出现，而是建立更强的 active / passive 层级：

- 当前可编辑区域更开放、更有生命感
- 已完成或暂时非活跃区域更往后退
- guidance 更贴近当前动作，而不是作为另一张竞争注意力的卡片

这不一定需要隐藏 section，本质上主要是 hierarchy 和 spacing 的调整。

#### C. Chip lanes 应该像“收集到的片段”，不是 mini cards

在 `SequentialSectionView.swift` 中，chips 和 input 最好读起来像一个连续的书写带，而不是“卡片里的 chips”。

建议方向：

- 更像 ribbon / lane 的横向组织
- 减少整个 section 外层的大卡片感
- 更清楚地区分 chips 和当前活跃输入框
- 让每个 section 有个性，但不改动数据模型

#### D. 长文本区域更像“页面区域”

`EditableTextSection.swift` 不应该只是又一个重复 block，而应该更像页面下方的真正书写区域。

目标变化：

- notes / reflections 前有更充分的呼吸感
- 少一些“又一张 section card”的感觉
- 更接近页面式的垂直节奏

### 具体改动方向

- 减少同时可见的完整边框 section wrapper 数量
- 让 section 标题更像页面结构的一部分，而不是盒子标题
- 调整 onboarding suggestion 和 tutorial hint 的位置与样式，让它们更像流程的一部分，而不是外插卡片
- 让 completion progression 轻微影响 emphasis 和色彩
- 在第一个输入框之前先把页面 identity 立住

### 验收意图

- Today 看起来像一张完整构成的页面，而不是模块堆叠
- 用户在 2 秒内能判断“下一步该写哪里”
- completion 和 guidance 给人的感觉是鼓励，而不是监督

---

## 2. Review

**主要涉及文件：**

- `Features/Journal/Views/ReviewScreen.swift`
- `Features/Journal/Views/ReviewSummaryCard.swift`

### 当前观感

Review 目前更像：

- 一个 mode picker
- 一个 insight card
- 一个 timeline list

可理解，但更像功能页而不是回顾页。

### 目标观感

Review 应该像在打开一封写给自己的周摘要。

### 建议层级

#### A. Hero insight first

当有 insight 时，页面第一屏应该先让用户看到 insight 本身，而不是先看到一个控件。

这意味着：

- 更突出 lead observation
- 降低 mode toggle 的视觉存在感
- 第一屏必须有非常清楚的阅读顺序

#### B. Narrative structure

现在的 `This week / A thread / A next step` 这套结构其实是好的，需要的是让它在视觉上更像 editorial digest：

- 一个 hero block
- 一个 supporting thread
- 一个 gentle next step
- activity 和 recurring themes 是证据层，而不是平权内容层

#### C. Timeline 成为次级内容

timeline 仍然有价值，但应该更像档案区或附录，而不是一个与 digest 主内容争主次的并行模式。

短期建议：

- 保留 segmented control，但把它做得更安静
- 让 Insights 很明确地成为默认和主导模式

长期建议：

- 评估 Timeline 是否更适合作为 Review 内的下层内容，而不是完全平行的 mode

### 具体改动方向

- 提高 hero insight 和 support blocks 的对比度
- 减少 insights 区域 “list 里的 row” 的感觉
- 降低 source/status 信息的视觉噪声
- 让 empty 和 loading 状态也属于回顾体验的一部分
- 让 timeline row 更像 calm archive，而不是 settings row

### 验收意图

- Review 第一屏应该立刻传达“这一周的意义”
- Insights 应该让人愿意读，且读起来像被设计过
- Timeline 应该支持回忆和查找，而不是把整个页面重新拉回列表工具感

---

## 3. Onboarding 与 post-Seed journey

**主要涉及文件：**

- `Features/Onboarding/OnboardingScreen.swift`
- `Features/Journal/Tutorial/PostSeedJourneyView.swift`
- `Features/Journal/Tutorial/PostSeedJourneyView+Pages.swift`
- `Features/Journal/Tutorial/JournalOnboardingSuggestionView.swift`
- `Features/Journal/Tutorial/JournalTutorialHintView.swift`

### 当前观感

这些流程和主题是一致的，但基本上还是在重复 app 现有的 card 语言。

### 目标观感

这些界面应该比主 app 稍微更有“进入感”和“仪式感”：

- 更像 arrival
- 更有叙事留白
- 更少重复通用 paper card

### 具体改动方向

- 给第一屏 onboarding 一个更有记忆点的视觉动作，而不是单张卡片加 CTA
- 让 post-Seed path model 更像一个品牌化的 journey artifact
- 减少 suggestion banner 像设置提示条那样的感觉
- 让 hint、suggestion、onboarding 三类内容在角色上更清晰区分，而不仅是 copy 不同

### 验收意图

- Onboarding 更像进入一个产品世界，而不是看一份说明
- Post-Seed guidance 应该深化成长隐喻，而不是只是在解释功能

---

## 4. Settings

**主要涉及文件：**

- `Features/Settings/SettingsScreen.swift`

### 当前观感

Settings 现在清晰、可用，但和 Review、Today 仍然共享了太多相同的视觉 DNA。

### 目标观感

Settings 应该比反思类页面更安静、更操作性、更不带情绪色彩。

### 具体改动方向

- 保持 settings practical、low-friction
- 尽量用更开放的 list rhythm，减少 paper-card 的强调
- 保留现在比较好的 title case 和 calm copy
- 让支持性 guidance 看起来可信赖，而不是像推广信息

### 验收意图

- Settings 要看起来是“有意为之的简单”，而不是“视觉上没做完”
- 它应明显属于同一个产品，但不和 Today / Review 争夺情绪中心

---

## 组件策略

## 1. 强化 `JournalCompletionPill`

它应该成为产品里最强的 recurring branded component。

当前角色：

- 一个有用的 completion chip

目标角色：

- 成长模型的视觉锚点
- Today、Review 和 onboarding 之间的桥梁

可扩展方向：

- 与等级对应的 accent 体系
- 通往教育卡片或 review surface 的共享过渡
- 更鲜明但依然克制的 level presence

---

## 2. 拆解 `SequentialSectionView`

`SequentialSectionView.swift` 现在承担了很多职责：

- guidance
- section heading
- progress dots
- chip lane
- add-chip affordance
- input
- loading/update overlay

为了后续设计迭代，建议至少在概念上先拆成更清晰的视觉角色：

- section heading / status
- chip lane
- draft input
- onboarding guidance treatment

这不一定意味着马上做一次大架构重构，但如果这些职责继续紧紧绑在一起，视觉系统很难优雅迭代。

---

## 3. 清楚地区分“信息型 UI”和“编辑型 UI”

需要让下面三类东西的视觉身份更明确：

- 用来读的
- 用来点的
- 用来写的

现在它们有时看起来过于相似。

建议通过以下方式拉开差异：

- surface role token
- typography role
- spacing rhythm
- border usage

---

## 4. 引入一小组可复用的视觉基础元件

建议往设计系统里补这些内容：

- page canvas 背景规则
- paper surface 变体
- input surface 变体
- section spacing 预设
- 标志性的 path / progression accent
- 更安静的 empty / loading state 处理

这些应该落在 `DesignSystem/Theme.swift` 和相关 shared modifier 附近，而不是在每个 screen 里重复发明。

---

## 实施阶段

## Phase 1：先在 Today 上建立新的视觉语言

**为什么先做**

Today 是核心循环，也是最能改变第一印象的页面。

**范围**

- 重做顶部 ritual header
- 减少 card 重复
- 提升 active-section hierarchy
- 重新组织长文本区域

**主要文件**

- `JournalScreen.swift`
- `DateSectionView.swift`
- `SequentialSectionView.swift`
- `EditableTextSection.swift`
- `Theme.swift`

---

## Phase 2：把 Review 重构成 digest

**为什么第二个做**

Review 是继 Today 之后最能建立产品识别度的界面。

**范围**

- hero insight hierarchy
- 更安静的 mode control
- 更有 digest 感的页面构成
- 更平静的 timeline 呈现

**主要文件**

- `ReviewScreen.swift`
- `ReviewSummaryCard.swift`
- `Theme.swift`

---

## Phase 3：对齐 onboarding 和辅助界面

**为什么第三步做**

核心产品语言先立住，再去统一 onboarding、hint、suggestion 会更稳。

**范围**

- onboarding 的 arrival feel
- post-Seed journey 的样式更新
- suggestion 和 hint 的角色区分

**主要文件**

- `OnboardingScreen.swift`
- `PostSeedJourneyView.swift`
- `PostSeedJourneyView+Pages.swift`
- `JournalOnboardingSuggestionView.swift`
- `JournalTutorialHintView.swift`

---

## Phase 4：壳层和最终 polish

**为什么放最后**

壳层应该反映最终语言，而不是在语言还没定之前反复调整。

**范围**

- tab icon 和 label 微调
- 标题处理
- 最后一轮 spacing 和 motion 打磨
- empty / loading / error state 统一

**主要文件**

- `GraceNotesApp.swift`
- `AppInterfaceAppearance.swift`
- 所有已触达页面上的 cross-app polish

---

## 设计验收清单

当满足以下条件时，这次改版可以认为是成功的：

- 新用户在第一分钟内，不会把这个 app 描述成“一个 journaling form”
- Today 有一个明显的视觉焦点，并更有 ritual 感
- Review 更像 weekly digest，而不是 utility screen
- 成长路径真正成为 Grace Notes 自己的视觉语言
- app 在减少 generic bordered card 的同时，没有损失清晰度
- Settings 依然简单、可信
- 动效依然平静且可访问

---

## 风险与边界

## 风险

- 矫正过头，变得太装饰化
- 无意中把 completion path 做得像 gamification
- 为了更美而让 Today 的输入效率下降
- 只改一个页面，结果造成整体视觉不一致

## 边界

- 必须保持编辑流程快速且明确
- 必须保留 Dynamic Type、VoiceOver、reduce motion、对比度支持
- 优先做构图和层级上的调整，而不是堆装饰
- 持续保持 emotional safety 和 low-pressure tone

---

## 实施前仍需确认的问题

1. Review 还是否要保持双 mode 结构，还是应该让 Timeline 下沉为 Insights 的附属内容？
2. app 壳层要离默认 iOS chrome 拉开多远，才不会伤害熟悉感？
3. 成长隐喻应该只出现在状态提示里，还是更直接地进入 section 布局？
4. 轻微 paper texture 是否值得它带来的实现和性能成本？

---

## 建议的下一步

如果这份方案被认可，最佳实施顺序建议是：

1. 先为 Today 单独开一个视觉方向 issue，并引用本文件
2. 只落地 Phase 1，不要和 Review 改版放进同一个 PR
3. 在设备上验证新的 Today hierarchy 是否真的更自然
4. 再基于这个结果推进 Review 的后续改版

