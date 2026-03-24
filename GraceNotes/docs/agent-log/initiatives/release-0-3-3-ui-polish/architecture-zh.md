---
initiative_id: release-0-3-3-ui-polish
role: Architect
status: in_progress
updated_at: 2026-03-18
related_release: 0.3.3
lang: zh-Hans
---

# 架构

## 已阅输入

- [GraceNotes/docs/agent-log/initiatives/release-0-3-3-ui-polish/brief.md](./brief.md)
- [GraceNotes/docs/07-release-roadmap.md](../../07-release-roadmap.md)
- [.impeccable.md](../../../../.impeccable.md)
- [.agents/skills/audit/SKILL.md](../../../../.agents/skills/audit/SKILL.md)
- [.agents/skills/polish/SKILL.md](../../../../.agents/skills/polish/SKILL.md)
- [.agents/skills/frontend-design/SKILL.md](../../../../.agents/skills/frontend-design/SKILL.md) 及参考文档
- [GraceNotes/GraceNotes/DesignSystem/Theme.swift](../../../GraceNotes/DesignSystem/Theme.swift)
- [GraceNotes/GraceNotes/Application/GraceNotesApp.swift](../../../GraceNotes/Application/GraceNotesApp.swift)
- [GraceNotes/GraceNotes/Application/StartupLoadingView.swift](../../../GraceNotes/Application/StartupLoadingView.swift)
- [GraceNotes/GraceNotes/Features/Onboarding/OnboardingScreen.swift](../../../GraceNotes/Features/Onboarding/OnboardingScreen.swift)
- [GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift](../../../GraceNotes/Features/Journal/Views/JournalScreen.swift)
- [GraceNotes/GraceNotes/Features/Journal/Views/ReviewScreen.swift](../../../GraceNotes/Features/Journal/Views/ReviewScreen.swift)
- [GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift](../../../GraceNotes/Features/Settings/SettingsScreen.swift)
- [GraceNotes/GraceNotes/Features/Settings/ReminderSettingsDetailScreen.swift](../../../GraceNotes/Features/Settings/ReminderSettingsDetailScreen.swift)

## 决策

将 `0.3.3` 作为一次有边界的跨界面 UI 精修版本发布，聚焦于现有流程的 cohesive、状态清晰度和沉稳收尾。本版本承接 `0.3.2` 中已发货的可靠性修复，旨在让已修复的流程呈现为「有意识地完成」而非仅「稳定可用」。明确排除重构工作、新功能范围，以及任何与规划中的 `0.4.0` 洞察质量版本形成的路线竞争。工作保持补丁级：仅对四个主要界面的呈现与一致性做 refinements，不改变产品形态。

## 目标

- 在 onboarding / 首次启动、今日、回顾、设置之间实现视觉与调性一致。
- 改进现有屏幕的间距、排版层级、文案一致性、标签和交互反馈。
- 让加载、空、成功、错误等状态呈现清晰、有意识地完成，而非突兀或视觉粗糙。
- 强化沉稳与信任 cues，使现有流程在 `0.3.2` 稳定性工作之后更有意图感。
- 使本版本可被诚实描述为精修与 cohesive，而非 disguised 功能版本。

## 非目标

- 不增加新产品功能、功能开关或会 materially 扩展应用能力的行为变更。
- 不进行信息架构重构、导航重组或大规模视觉 rebrand。
- 不包含 `0.4.0` 洞察质量工作：更强的回顾摘要、AI 提示改动或新回顾机制。
- 不扩展信任层：导入、同步、备份或隐私控制。
- 不进行性能调查，除非需要细微的呈现修复以使已发货流程更易理解。
- 不扩展深色模式；应用保持以浅色模式为主，深色模式 token 工作延后。

## 技术范围

### 精修维度（与 SwiftUI 相关）

| 维度 | SwiftUI 语境下的「完成」标准 |
|------|-----------------------------|
| **视觉对齐与间距** | 在可行处使用共享间距/圆角 token；列表/卡片内边距一致；图标与文字光学对齐；不再散落字面量（如重复的 `padding(8)`、`cornerRadius: 14`），改为使用共享常量。 |
| **排版层级** | 一致使用 `AppTheme.warmPaperHeader` 和 `warmPaperBody`；导航标题、区块标题、正文、元数据、状态标签的层级稳定；在适用处使用 Dynamic Type 安全尺寸。 |
| **颜色与对比** | 语义化使用 `AppTheme` token；不在应用品牌界面使用硬编码 `.foregroundStyle(.white)` 或 `.foregroundStyle(.red)`；错误/成功表面在存在时使用主题派生颜色。文本对比度满足 WCAG AA。 |
| **交互状态** | 可点击控件的默认、按下、禁用、加载状态；映射到 SwiftUI 的 `ButtonStyle`、`disabled`、`ProgressView` 及既有模式。错误与成功使用明确消息（alert、内联文案、toast）。 |
| **加载/空/错误/成功** | 各主要界面在相关处有明确、沉稳的文案和视觉一致的状态容器。避免泛泛的「加载中」；空状态要 acknowledgment 并引导。 |
| **文案与标签** | 术语与大小写在标签页、区块、按钮、alert、辅助文案、空状态中统一。语调按 `.impeccable.md`：沉稳、温暖、支持性。 |

### 界面清单与有界精修项

#### 1. Onboarding 与首次启动

| 文件 | 有界精修项 |
|------|------------|
| `StartupLoadingView.swift` | 将重试按钮的 `.foregroundStyle(.white)` 改为主题派生前景色；确保加载/重试/禁用状态在视觉上可区分；间距与圆角与共享 token 对齐。 |
| `OnboardingScreen.swift` | 将主 CTA 的 `.foregroundStyle(.white)` 改为主题派生前景色；卡片内边距与圆角与其他界面一致；确保「继续」/「开始」层级与点按反馈一致。 |

#### 2. 今日 / 日记

| 文件 | 有界精修项 |
|------|------------|
| `JournalScreen.swift` | 将保存错误的 `.foregroundStyle(.red)` 替换为 `AppTheme` 语义错误色（如缺失则添加）；分享 alert 文案要具体、沉稳；区块间间距对齐。 |
| `SequentialSectionView.swift`, `EditableTextSection.swift`, `ChipView.swift`, `DateSectionView.swift` | 间距与层级一致；输入/卡片样式与 `WarmPaperInputStyle` 和 paper token 对齐；chip 与区块布局使用共享间距。 |

#### 3. 回顾（洞察 + 时间线）

| 文件 | 有界精修项 |
|------|------------|
| `ReviewScreen.swift` | 洞察卡片内的加载 spinner；空状态文案与布局；分段选择器与列表行对齐；`ReviewSummaryCard` 与 `HistoryRow` 间距/层级；完成徽章 chip 样式与主题对齐。 |

#### 4. 设置

| 文件 | 有界精修项 |
|------|------------|
| `SettingsScreen.swift` | 导出 overlay 与按钮禁用/加载处理；alert 文案一致性（避免泛泛「确定」，在适当时使用「关闭」或具体动作标签）；页脚与区块标题层级。 |
| `ReminderSettingsDetailScreen.swift` | 按钮层级（bordered vs borderedProminent）及禁用/加载状态；状态文案与指引语调；控件与区块间距。 |

### 共享主题扩展（限 0.3.3 需要）

- 若保存/分享/alert 错误表面需要主题派生替代 `.red`，则向 `AppTheme` 添加语义 `error`（或等价）颜色。
- 仅在能减少重复与不一致时添加共享间距/圆角常量；避免过度工程。
- 不引入完整设计 token 系统；对现有 `AppTheme` 做最小扩展。

### Impeccable-Style 技能使用

Impeccable-style 技能为本精修版本的系统性审查与执行框架，用于划定、优先级排序和验证工作——**而非**扩展范围。使用方式如下：

| 技能 | 使用时机 | 范围约束 |
|------|----------|----------|
| `/audit` | 在实现前于四个在 scope 内的界面建立优先级化的质量清单；也可在结束时用于跨界面验证。 | 审计结论必须映射到在 scope 内的精修维度；超出 scope 的项延后。 |
| `/polish` | **必须**在每个界面级实现 pass 后、以及最终跨界面 pass 中执行。验证间距、排版、交互状态、文案与状态处理。 | 使用 polish checklist；不添加新功能或重构。 |
| `frontend-design` | 作为所有精修工作的风格质量基础与反模式检查。 | 适配 SwiftUI/iOS；不照抄 web/CSS 模式。 |
| `teach-impeccable` | **条件使用**：仅当 `.impeccable.md` 不再提供足够设计上下文时运行。0.3.3 以 `.impeccable.md` 为认可来源。 | 若设计上下文充足则跳过。 |

**辅助技能**（仅当发现集中在某一维度且能干净映射到在 scope 内的精修时使用）：

| 维度聚类 | 建议技能 | 使用时机 |
|----------|----------|----------|
| 间距、节奏、对齐、内边距 | `/arrange` | 布局单调或不一致；间距/圆角在界面内离散。 |
| 排版层级、字号、字重 | `/typeset` | 字体使用或层级不一致；可读性或缩放问题。 |
| 标签、alert、空/错误文案 | `/clarify` | 文案模糊、泛泛或语调不一致；标签需规范化。 |
| 主题/token 一致性 | `/normalize` | 硬编码颜色或数值；视觉模式偏离 `AppTheme`。 |
| 加载、空、错误、成功状态 | `/harden` | 状态文案或边缘情况处理薄弱或缺失。 |

## 受影响区域

- `GraceNotes/GraceNotes/DesignSystem/Theme.swift` — 可选语义错误色与间距/圆角常量
- `GraceNotes/GraceNotes/Application/StartupLoadingView.swift` — CTA 前景、状态样式
- `GraceNotes/GraceNotes/Features/Onboarding/OnboardingScreen.swift` — CTA 前景、卡片间距
- `GraceNotes/GraceNotes/Features/Journal/Views/JournalScreen.swift` — 保存错误样式、alert 文案
- `GraceNotes/GraceNotes/Features/Journal/Views/SequentialSectionView.swift`, `EditableTextSection.swift`, `ChipView.swift`, `DateSectionView.swift` — 间距与层级
- `GraceNotes/GraceNotes/Features/Journal/Views/ReviewScreen.swift` — 加载、空、卡片、行精修
- `GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift` — 导出 overlay、alert 文案
- `GraceNotes/GraceNotes/Features/Settings/ReminderSettingsDetailScreen.swift` — 按钮与状态精修

## 风险与边缘情况

- 精修可能蔓延：严守界面清单与维度 checklist；避免「既然在这了」式重构。
- 跨应用清理可能暴露出诱使更广重构的不一致：明确延后；记作后续项。
- 多小改动会增加回归风险：每界面运行 polish 技能并在合并前验证 close 标准。
- 硬编码颜色替换（`.red`、`.white`）不得降低对比度或违反可访问性预期。
- Dynamic Type 与 VoiceOver：验证在更大字号及开启可访问性功能时层级与触控区域仍可用。
- `prefers-reduced-motion`：在存在过渡处遵守；不引入忽略此偏好的新动画。

## 执行顺序

1. **审计** — 在 0.3.3 全 scope（onboarding、首次启动、今日、回顾、设置）上运行 `/audit`。建立优先级化缺陷清单并识别系统性问题。用审计报告驱动共享基础与界面工作；**勿**将审计发现当作 scope 扩展——仅处理映射到在 scope 内精修维度的项。
2. **共享精修基础** — 仅在审计显示有重复 token/间距/状态问题时，添加所需最小主题扩展（如语义错误色、1–2 个间距常量）。将 scope 限制在 0.3.3 明确需要的范围内。
3. **首次启动与 onboarding** — 对 `StartupLoadingView` 与 `OnboardingScreen` 实施精修。若问题聚集（如布局、文案、状态处理），先运行最窄相关技能（`/arrange`、`/clarify`、`/harden`）。**然后**在本界面上运行 `/polish` 再继续。在设备上验证第一印象。
4. **今日 / 日记** — 对 `JournalScreen` 与共享日记组件实施精修。若发现聚集则运行辅助技能。**然后**在本界面上运行 `/polish`。验证保存/分享/错误流程与区块一致性。
5. **回顾** — 对 `ReviewScreen`、洞察卡片、空状态、时间线行实施精修。必要时运行辅助技能。**然后**在本界面上运行 `/polish`。验证洞察与时间线模式。
6. **设置** — 对 `SettingsScreen` 与 `ReminderSettingsDetailScreen` 实施精修。必要时运行辅助技能。**然后**在本界面上运行 `/polish`。验证导出与提醒流程。
7. **跨界面验证** — 在所有界面上运行一次 `/polish`。做一次全局一致性排查（术语、大小写、视觉节奏）。可选再次运行 `/audit` 做最终验证。确认无主要界面在发布后明显粗糙于其他界面。

## 完成标准

- 应用在 onboarding、首次启动、今日、回顾、设置间呈现视觉与调性一致。
- 现有流程清晰传达状态：用户不须猜测应用是否在加载、保存、启用、禁用或已完成。
- 文案、间距与交互反馈沉稳、有意图，而非混杂或随意。
- 发布后无主要界面明显比其他界面粗糙或欠考量。
- 本版本可被诚实描述为精修与 cohesive，而非 disguised 功能版本。
- 应用品牌主要界面无硬编码 `.foregroundStyle(.red)` 或 `.foregroundStyle(.white)`；错误与 CTA 样式使用主题派生值。
- 加载、空、错误、成功状态在存在处有明确、沉稳的文案。
- Alert 与按钮标签在具体动作标签更清晰时避免泛泛「确定」。
- 在设备上进行人工验证：浅色模式、Dynamic Type、VoiceOver 标签/焦点、按钮禁用/加载状态、触控区域、视觉节奏。

## 实现交接

- **实现者**：
  - 在四个在 scope 内界面上先运行 `/audit` 建立优先级化缺陷清单；用发现驱动工作但**勿**扩展到在 scope 内的精修维度之外。
  - 在完成某界面编辑后**按界面**运行 `/polish`，而非仅在最后运行一次。以 polish 技能 checklist（视觉对齐、排版、颜色、交互状态、文案、边缘情况）作为各界面验证步骤。
  - 当某界面暴露出聚集问题时，先使用最窄相关技能（`/arrange`、`/typeset`、`/clarify`、`/normalize`、`/harden`），再在继续前运行 `/polish`。
  - 以一次跨所有界面的最终 `/polish` pass 收尾；可选再次运行 `/audit` 验证。
- **frontend-design 指引**：视为品味与系统质量输入；适配 iOS 与 SwiftUI 约定，而非照抄 web/CSS 模式。
- **teach-impeccable**：仅当 `.impeccable.md` 不再为后续精修工作提供足够设计上下文时运行。0.3.3 以 `.impeccable.md` 为认可来源。
- **测试负责人**：在设备上验证完成标准；确认除 intentional 精修外无行为变更；检查可访问性与状态传达。

## 待决问题

- 0.3.3 是否应明确保持仅浅色模式（建议本版本保持；深色模式 token 工作延后）。
- 本版本是否应有一项可见、值得写入 changelog 的 headline，或仅以广义 cohesive pass 形式发布。
- 是否需要在现有应用字符串之外建立明确的产品术语表（若无文案规范化冲突则延后）。

## 下一负责人

`Builder`，随后 `Test Lead`，负责执行先审计、再按界面精修的顺序（先运行 `/audit`，再按界面运行 `/polish`，最后跨界面验证），验证完成标准，确保本版本呈现为精修与 cohesive 而非功能扩展。
