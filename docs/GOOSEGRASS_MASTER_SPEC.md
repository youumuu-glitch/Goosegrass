# Goosegrass
## macOS 客户预约管理 App —— 产品架构、工程规范与 Codex 自主执行文档

> 文档用途：交给 Codex / Coding Agent 直接作为长期执行基线。  
> 产品名称：**Goosegrass**  
> 当前目标平台：**macOS**  
> 当前开发者主机：**Windows**  
> 当前产品模式：**Local First / Single User / Offline First**  
> 未来预留：账号登录、云同步、多设备、团队协作、平台 API 导入。  
> 文档目标：让 Codex 在尽量低人工干预的情况下，持续把 Goosegrass 朝“真实可用、可测试、可备份、可维护”的桌面产品推进，而不是只生成 Demo。

---

# 0. Codex 执行总则

## 0.1 最高优先级

Codex 必须始终按以下优先级执行：

1. **数据安全与不丢数据**
2. **预约业务逻辑正确**
3. **客户不漏记、预约不漏提醒**
4. **可恢复、可追溯**
5. **macOS 原生体验**
6. **可维护的工程结构**
7. **视觉美观**
8. **未来扩展能力**

视觉效果不得凌驾于数据正确性和业务可靠性之上。

---

## 0.2 不得擅自改变的技术方向

除非用户明确批准，否则 Codex **不得**将项目改为：

- Electron
- Tauri
- Flutter
- React Native
- Web App 套壳
- Python GUI
- Qt
- Windows 原生 App
- iOS App
- 浏览器 SaaS

Goosegrass 当前正式方向固定为：

- Swift
- SwiftUI
- SwiftData
- UserNotifications
- 原生 macOS App
- Local First

理由：产品的目标体验是 Apple 原生桌面 App，而不是跨平台桌面程序。

---

## 0.3 Windows 主机约束

当前开发者日常使用 Windows。

因此 Codex 必须认识到：

- Windows 可以完成：
  - Git 管理
  - 产品文档
  - 业务模型设计
  - 大部分 Swift 源码编写
  - 纯 Swift Domain 层设计
  - 测试设计
  - CI 配置
  - 静态代码检查
  - 数据结构定义
  - Mock 数据
  - 文档维护

- Windows **不能作为最终 macOS 原生 App 的完整构建与验收环境**。
- Xcode 的正式安装和 macOS App 的真实构建、签名、运行、权限、通知、视觉表现必须在 macOS 环境完成。

### 推荐工作模式

```text
Windows + Codex
      │
      │ Git push
      ▼
Git Repository
      │
      ├── GitHub Actions macOS Runner
      │       └── Build / Unit Test / Compile Gate
      │
      └── Real Mac / Remote Mac
              └── Xcode / UI / Notification / Signing / Manual QA
```

### 强制规则

Codex 不得在 Windows 环境下声称：

- “macOS App 已成功运行”
- “Xcode 构建通过”
- “通知已经真实弹出”
- “UI 在 Mac 上显示正确”
- “签名成功”
- “DMG / App Store 发布成功”

除非有真实 macOS 构建日志或 Mac 验证证据。

---

# 1. 产品定义

## 1.1 产品名称

**Goosegrass**

---

## 1.2 产品定位

Goosegrass 是一款面向需要管理大量客户线索与预约记录的个人经营者、销售人员、门店负责人或服务人员的 **macOS 本地客户预约工作台**。

它不是单纯的日历，也不是重型 CRM。

产品核心定位：

> **客户线索 + 预约 + 提醒 + 跟进 + 历史追踪**

---

## 1.3 核心用户痛点

典型场景：

- 从小红书、抖音、大众点评、微信、电话、广告平台等渠道获取大量客户。
- 客户信息来源分散。
- 依赖聊天记录、便签或人工记忆。
- 客户数量增长后无法保证逐个记录。
- 长时间后容易忘记客户是谁。
- 容易忘记预约时间。
- 客户改时间后原信息容易被覆盖。
- 未到店客户容易被遗忘。
- 同一客户多次咨询容易被重复创建。
- 无法快速知道今天谁会到店。
- 无法快速找到需要再次联系的人。

Goosegrass 要解决：

> **不漏客户、不忘预约、不记错客户、不丢历史。**

---

# 2. 产品原则

## 2.1 Local First

V1 所有核心数据默认存储在本机。

无需：

- 注册
- 登录
- 云服务器
- 网络连接

应用离线必须可正常工作。

---

## 2.2 Customer First

客户是长期实体。

预约只是客户的事件之一。

错误结构：

```text
Appointment
- name
- phone
- time
```

正确结构：

```text
Customer
   ├── Appointment
   ├── Appointment
   ├── Activity
   ├── FollowUp
   └── Notes
```

一个客户可以拥有多次预约。

---

## 2.3 History First

修改重要业务数据时不得直接抹掉历史。

例如预约改期：

错误：

```text
2026-09-20 15:00
直接改成
2026-09-22 16:30
```

正确：

```text
Original
2026-09-20 15:00

Rescheduled
2026-09-22 16:30

Reason
客户要求改时间

Changed At
2026-09-19 13:20
```

---

## 2.4 Reminder First

已经确认的预约必须能够建立可靠提醒。

预约改期或取消时：

- 旧通知取消
- 新通知重建
- 防止重复通知
- 防止幽灵提醒

---

## 2.5 Recoverable First

任何用户关键数据都必须考虑：

- 备份
- 恢复
- 导出
- 删除确认
- 数据迁移

---

# 3. V1 成功标准

Goosegrass V1 达标必须满足以下真实工作闭环：

```text
客户进入
   ↓
创建 / 导入
   ↓
去重
   ↓
待处理
   ↓
联系
   ↓
创建预约
   ↓
提醒
   ↓
客户到店
   ├── 已到店
   ├── 改期
   ├── 未到店
   └── 取消
        ↓
      跟进
        ↓
    后续再次预约
```

任何一环不得依赖外部服务器。

---

# 4. 信息架构

主导航建议：

```text
Today
Inbox
Appointments
Calendar
Customers
Follow-up
History
Settings
```

中文显示可采用：

```text
今日
收件箱
预约
日历
客户
待跟进
历史
设置
```

---

# 5. 页面规格

# 5.1 Today —— 今日工作台

这是默认首页。

目标：

> 用户打开 Goosegrass 后 5 秒内知道今天最重要的事情。

顶部数据卡建议：

- 今日预约
- 即将到店
- 待联系
- 未到店

要求：

- 卡片简洁
- 支持点击作为筛选入口
- 不做复杂 BI 仪表盘

主内容按时间排序：

```text
09:30 王女士   2人   已确认
11:00 李先生   1人   即将到店
14:00 张女士   3人   待确认
16:30 赵先生   2人   已改期
```

每条预约显示：

- 时间
- 客户名称
- 人数
- 电话尾号
- 来源
- 状态
- 标签
- 关键要求摘要

快捷操作：

- 已到店
- 改期
- 未到店
- 取消
- 打开详情

---

# 5.2 Inbox —— 客户收件箱

用于处理刚进入系统、尚未整理的客户。

客户来源：

- 手动新增
- CSV 导入
- 批量文本粘贴
- 未来平台 API
- 未来智能解析

Inbox 状态：

- New
- Need Contact
- Contacted
- Need Confirm
- Converted
- Invalid

主要操作：

- 创建预约
- 标记已联系
- 创建跟进
- 合并重复客户
- 标记无效
- 归档

---

# 5.3 Appointments —— 预约列表

支持：

- 全部预约
- 今天
- 明天
- 本周
- 自定义日期
- 状态筛选
- 客户筛选
- 来源筛选
- 标签筛选

建议表格列：

- 日期
- 时间
- 客户
- 电话
- 人数
- 来源
- 状态
- 提醒状态
- 要求摘要
- 最后更新时间

---

# 5.4 Calendar —— 日历

支持：

- 月
- 周
- 日

V1 优先：

- 月视图
- 日详情
- 周视图可在后续阶段加入

点击日期：

右侧 Inspector 显示该日预约。

禁止为了日历视觉复杂度牺牲可维护性。

---

# 5.5 Customers —— 客户库

列表字段：

- 姓名
- 电话
- 来源
- 当前状态
- 标签
- 最近联系
- 下次预约
- 最近备注

支持搜索：

- 姓名
- 电话
- 电话尾号
- 备注关键词
- 标签
- 来源

---

# 5.6 Customer Detail —— 客户详情

顶部：

- 客户姓名
- 电话
- 来源
- 标签
- 当前状态
- 首次进入时间
- 最近联系时间

主要操作：

- 新建预约
- 创建跟进
- 编辑客户
- 添加备注
- 复制电话
- 归档

主体使用 Timeline。

示例：

```text
2026-09-22
已到店

2026-09-21
预约确认

2026-09-20
预约改期
09-20 15:00 → 09-22 14:30

2026-09-18
第一次联系

2026-09-17
来自小红书推广
```

---

# 5.7 Follow-up —— 待跟进

典型来源：

- 新客户未联系
- 已联系待确认
- 未到店客户
- 改期后待确认
- 用户手动创建
- 取消后要求后续联系

字段：

- 客户
- 跟进时间
- 跟进原因
- 优先级
- 状态
- 备注

状态：

- Pending
- Done
- Snoozed
- Cancelled

---

# 5.8 History —— 历史

显示：

- 已完成预约
- 已取消
- 未到店
- 已归档客户
- 历史跟进

默认只读优先。

删除应作为受控操作。

---

# 5.9 Settings —— 设置

V1 设置包括：

### General

- 启动默认页面
- 日期格式
- 时间格式

### Notifications

- 默认提前一天
- 默认提前两小时
- 默认提前 30 分钟
- 声音开关

### Data

- 数据库位置说明
- 立即备份
- 自动备份开关
- 备份保留数量
- 恢复备份
- 导出数据

### Import

- CSV 导入
- 列映射
- 最近导入记录

### Privacy

- 本地数据说明
- 清除数据

未来：

- Account
- Sync
- Team

---

# 6. 快速录入

快捷键：

```text
⌘N
```

打开 Quick Add。

目标：

> 10 秒内完成常见预约录入。

字段：

- 客户
- 电话
- 日期
- 时间
- 人数
- 客户要求
- 备注
- 提醒

支持：

- 搜索现有客户
- 新客户直接创建

未来：

支持粘贴：

```text
李女士 186xxxx8888 周日下午3点 3人 希望安静一点
```

自动解析字段。

V1 不依赖 AI。

---

# 7. 全局搜索

快捷键：

```text
⌘K
```

可搜索：

- 客户姓名
- 电话
- 电话尾号
- 预约
- 备注
- 标签
- 来源

结果按：

1. Customer
2. Appointment
3. Follow-up

分类展示。

---

# 8. 状态机

# 8.1 CustomerStatus

```swift
enum CustomerStatus {
    case new
    case needContact
    case contacted
    case needConfirm
    case booked
    case active
    case followUp
    case dormant
    case invalid
    case archived
}
```

注意：

CustomerStatus 是客户当前经营状态，不等同于预约状态。

---

# 8.2 AppointmentStatus

必须独立。

建议：

```swift
enum AppointmentStatus {
    case draft
    case pendingConfirmation
    case confirmed
    case upcoming
    case arrived
    case completed
    case rescheduled
    case noShow
    case cancelled
}
```

核心合法流转：

```text
draft
  ↓
pendingConfirmation
  ↓
confirmed
  ↓
upcoming
  ├── arrived → completed
  ├── rescheduled
  ├── noShow
  └── cancelled
```

Rescheduled 后：

- 原 Appointment 保留历史
- 新预约可创建新 Appointment
- 或使用 revision/history 模型记录变更

Codex 必须选择一种一致策略，不得同时混用。

推荐：

> 保留同一 Appointment ID，同时创建 AppointmentChange 变更历史。

若业务后续证明需要拆分，再升级模型。

---

# 8.3 FollowUpStatus

```swift
enum FollowUpStatus {
    case pending
    case completed
    case snoozed
    case cancelled
}
```

---

# 9. 核心数据模型

所有主实体建议使用 UUID。

所有实体原则上加入：

```text
id
createdAt
updatedAt
```

未来同步需要的实体预留：

```text
syncStatus
serverID
lastSyncedAt
```

V1 可以字段存在但不实现云同步。

---

# 9.1 Customer

字段建议：

```text
id: UUID
displayName: String
legalName: String?
phone: String
normalizedPhone: String
email: String?
sourceID: UUID?
status: CustomerStatus
notes: String
isArchived: Bool
createdAt: Date
updatedAt: Date
lastContactedAt: Date?
```

关系：

```text
appointments[]
activities[]
followUps[]
tags[]
```

约束：

- normalizedPhone 用于去重
- 电话不是绝对唯一，因为家庭/公司共用号码可能存在
- 检测重复时提示，不默认阻止
- 合并重复客户必须保留双方历史

---

# 9.2 Appointment

字段：

```text
id: UUID
customerID: UUID
startAt: Date
endAt: Date?
partySize: Int
status: AppointmentStatus
customerRequest: String
internalNote: String
sourceID: UUID?
confirmedAt: Date?
arrivedAt: Date?
completedAt: Date?
cancelledAt: Date?
noShowAt: Date?
createdAt: Date
updatedAt: Date
```

规则：

- partySize >= 1
- startAt 必填
- cancelled / noShow / completed 需要对应时间
- 所有状态变化写 Activity

---

# 9.3 AppointmentChange

用于改期和关键字段变化。

```text
id
appointmentID
changeType
oldValueJSON
newValueJSON
reason
changedAt
```

ChangeType：

```text
rescheduled
partySizeChanged
statusChanged
noteChanged
requestChanged
```

---

# 9.4 Reminder

```text
id
appointmentID
type
fireAt
systemNotificationID
status
createdAt
updatedAt
```

ReminderType：

```text
oneDayBefore
twoHoursBefore
thirtyMinutesBefore
custom
```

ReminderStatus：

```text
scheduled
delivered
cancelled
failed
```

---

# 9.5 FollowUp

```text
id
customerID
appointmentID?
dueAt
reason
note
priority
status
completedAt?
createdAt
updatedAt
```

---

# 9.6 Activity

用于客户时间线。

```text
id
customerID
appointmentID?
type
title
detail
createdAt
```

典型 type：

```text
customerCreated
customerImported
contacted
appointmentCreated
appointmentConfirmed
appointmentRescheduled
appointmentArrived
appointmentCompleted
appointmentNoShow
appointmentCancelled
followUpCreated
followUpCompleted
noteAdded
customerMerged
```

---

# 9.7 LeadSource

```text
id
name
iconName?
isActive
createdAt
```

默认来源：

- 小红书
- 抖音
- 大众点评
- 微信
- 电话
- 朋友介绍
- 线下
- 其他

---

# 9.8 Tag

```text
id
name
createdAt
```

默认不强制预置。

用户可创建：

- 高意向
- VIP
- 老客户
- 价格敏感
- 需重点跟进

---

# 9.9 ImportBatch

```text
id
fileName
sourceType
totalRows
createdRows
updatedRows
duplicateRows
failedRows
createdAt
```

用于追踪批量导入。

---

# 9.10 AppSettings

配置：

- reminder presets
- backup settings
- UI preferences
- date/time settings

不要把敏感凭据存 AppSettings。

未来账户 token 使用 Keychain。

---

# 10. 数据访问架构

禁止 View 直接承担复杂数据库操作。

推荐：

```text
UI
  ↓
ViewModel
  ↓
Service
  ↓
Repository
  ↓
SwiftData
```

目录逻辑：

```text
Presentation
Domain
Application
Infrastructure
```

建议：

```text
Goosegrass/
├── App/
├── Domain/
│   ├── Models/
│   ├── Enums/
│   └── Rules/
├── Application/
│   ├── Services/
│   ├── UseCases/
│   └── DTO/
├── Infrastructure/
│   ├── Persistence/
│   ├── Notifications/
│   ├── Backup/
│   ├── Import/
│   └── Export/
├── Features/
│   ├── Today/
│   ├── Inbox/
│   ├── Appointments/
│   ├── Calendar/
│   ├── Customers/
│   ├── FollowUp/
│   ├── History/
│   └── Settings/
├── Shared/
│   ├── Components/
│   ├── DesignSystem/
│   ├── Extensions/
│   └── Utilities/
└── Tests/
```

---

# 11. Repository 设计

协议示例：

```swift
protocol CustomerRepository {
    func create(...)
    func update(...)
    func fetch(...)
    func search(...)
    func archive(...)
}
```

未来：

```text
CustomerRepository
   ├── LocalCustomerRepository
   └── RemoteCustomerRepository
```

V1 只实现 Local。

这样未来账户与云同步不会污染 UI。

---

# 12. Service 设计

至少包括：

```text
CustomerService
AppointmentService
ReminderService
FollowUpService
ImportService
BackupService
ExportService
SearchService
```

---

# 13. AppointmentService 核心职责

必须集中处理：

- 创建预约
- 编辑预约
- 确认预约
- 到店
- 完成
- 未到店
- 取消
- 改期
- 写 Activity
- 调 ReminderService

不得把这些规则分散在各个 View。

---

# 14. ReminderService

使用 Apple UserNotifications。

职责：

```text
requestPermission()
schedule()
reschedule()
cancel()
rebuildForAppointment()
reconcilePendingNotifications()
```

创建预约时：

```text
Appointment
   ↓
ReminderService
   ↓
UNUserNotificationCenter
```

改期：

```text
cancel old
schedule new
```

取消：

```text
cancel all appointment reminders
```

启动 App 时建议执行轻量 reconcile：

- 检查未来预约
- 检查数据库 Reminder
- 检查系统 pending notifications
- 修复明显不一致

避免重复创建。

---

# 15. ImportService

V1 至少支持 CSV。

建议第二优先级支持：

- TSV
- 批量文本粘贴

导入流程：

```text
Select File
   ↓
Preview
   ↓
Column Mapping
   ↓
Normalize
   ↓
Duplicate Detection
   ↓
User Review
   ↓
Import
   ↓
Import Summary
```

严禁选择文件后直接入库。

---

# 16. 电话号码规范化

normalizedPhone 至少：

- 去空格
- 去 `-`
- 去括号

国际区号处理要谨慎。

V1 不做复杂国家识别时：

- 保留原始 phone
- normalizedPhone 用于辅助匹配
- 重复检测只作为提醒
- 不得自动删除

---

# 17. BackupService

这是 V1 强制能力。

## 17.1 目标

数据库损坏、误操作或电脑更换时可恢复。

## 17.2 V1 功能

- 立即备份
- 自动每日备份
- 保留最近 N 份
- 查看备份
- 恢复前再次创建安全备份
- 恢复后重新启动数据容器

默认建议：

```text
Retention = 30
```

## 17.3 恢复要求

恢复流程：

```text
选择备份
↓
校验
↓
警告
↓
当前数据安全备份
↓
恢复
↓
重新加载
↓
完整性检查
```

若 SwiftData 存储由多个文件组成，必须整体一致复制。

Codex 不得只复制一个文件就认为备份可靠。

---

# 18. ExportService

V1：

- Customers CSV
- Appointments CSV

未来：

- JSON
- PDF 日报
- Excel

导出必须 UTF-8。

---

# 19. 删除策略

关键业务实体优先软删除/归档。

Customer：

- 默认 Archive
- 不直接永久删除

Appointment：

- 默认 Cancel
- 非必要不删除

永久删除：

- 设置中高级操作
- 二次确认
- 明确影响范围

---

# 20. UI 技术

正式 UI：

```text
SwiftUI
NavigationSplitView
Inspector
Toolbar
Table
List
Form
Popover
Sheet
ContextMenu
Commands
```

尽量使用 macOS 原生组件。

---

# 21. Apple 风格 / Glass UI

目标不是“全屏透明”，而是：

> 原生、克制、有层次、清晰。

玻璃效果适用：

- Sidebar
- Toolbar
- Floating Controls
- Popover
- Inspector Header
- Quick Add
- Filter Bar

正文内容：

- 保持高可读性
- 不过度透明

---

# 22. 系统版本策略

建议 V1 最低部署目标：

> **macOS 14 或 Codex 根据当前 SwiftData / 项目工具链确认后的合理最低版本**

原因：

- SwiftData 是核心持久化方案。
- 不应为了最新 UI API 强行把所有用户限制在最新 macOS。

Glass 策略：

```text
macOS 26+
    使用可用的新版系统 Glass / Liquid Glass API

较低支持版本
    使用 SwiftUI Material / 原生背景进行视觉降级
```

要求：

- 业务功能不依赖 Liquid Glass
- 新 UI API 必须做 Availability 保护
- 不允许因为视觉 API 导致老系统崩溃

---

# 23. Design System

建立统一 Token。

## 23.1 Spacing

建议：

```text
4
8
12
16
20
24
32
```

## 23.2 Corner Radius

```text
Small  = 8
Medium = 12
Large  = 16
Hero   = 20
```

系统原生控件优先，不强制覆盖系统圆角。

## 23.3 Typography

优先系统字体：

- `.title`
- `.title2`
- `.headline`
- `.body`
- `.caption`

不要手工指定第三方字体。

## 23.4 Icons

优先：

**SF Symbols**

---

# 24. 三栏布局

核心桌面布局：

```text
┌───────────────┬───────────────────────────┬──────────────────┐
│ Sidebar       │ Main Content              │ Inspector        │
│               │                           │                  │
│ Today         │ Appointments / Customers  │ Detail           │
│ Inbox         │                           │                  │
│ Appointments  │                           │                  │
│ Calendar      │                           │                  │
│ Customers     │                           │                  │
│ Follow-up     │                           │                  │
│ History       │                           │                  │
│ Settings      │                           │                  │
└───────────────┴───────────────────────────┴──────────────────┘
```

Inspector 可关闭。

---

# 25. 键盘快捷键

至少：

```text
⌘N          新建预约 / Quick Add
⌘K          全局搜索
⌘F          当前页面搜索
⌘,          Settings
⌘R          刷新 / 根据上下文使用
Esc         关闭 Sheet / Popover
```

避免覆盖系统常见快捷键含义。

---

# 26. 通知 UX

首次启动不得立刻弹权限。

建议：

1. 用户第一次创建带提醒的预约。
2. Goosegrass 解释为什么需要通知。
3. 用户点击“允许提醒”。
4. 再请求系统权限。

拒绝权限后：

- App 不崩溃
- 预约仍可保存
- UI 明确提醒“系统通知未启用”
- 提供打开系统设置入口（如系统 API 支持）

---

# 27. 空状态

每个主要页面必须有 Empty State。

例：

Today：

> 今天暂时没有预约。

Inbox：

> 所有新客户都处理完了。

Customers：

> 还没有客户，创建第一位客户或导入 CSV。

禁止空白白屏。

---

# 28. 错误处理

任何数据库、导入、备份、通知错误：

- 用户可理解
- 不暴露底层堆栈
- 日志保留技术信息
- 提供重试
- 不导致现有数据丢失

---

# 29. 日志

V1 使用轻量日志。

禁止日志写：

- 完整电话号码
- 大段客户隐私备注
- 未来密码
- token

允许：

```text
Appointment saved: <UUID>
Reminder schedule failed: <UUID>
Import completed: 120 / 4 duplicate / 2 failed
```

---

# 30. 隐私与本地数据

Goosegrass 存储：

- 姓名
- 电话
- 预约
- 备注

这些属于敏感业务/个人信息。

V1：

- 默认不上传服务器
- 不做隐藏遥测
- 不做广告 SDK
- 不做第三方分析 SDK

未来接入网络功能时必须更新隐私说明。

未来登录凭据：

- Keychain

不得：

- UserDefaults 保存 token
- 明文配置文件保存密码

---

# 31. 数据完整性

Codex 必须为以下场景编写测试：

1. 新建客户。
2. 同电话客户重复检测。
3. 新建预约。
4. 改期。
5. 改期后旧提醒取消。
6. 取消预约后提醒取消。
7. 未到店后创建跟进。
8. 客户历史仍完整。
9. CSV 导入重复数据。
10. 备份恢复后记录数量一致。

---

# 32. Testing Strategy

分层：

## Unit Tests

测试：

- Domain Rules
- Status Transition
- Phone Normalization
- Appointment Validation
- Import Mapping
- Reminder Calculation

## Repository Tests

测试：

- CRUD
- Search
- Relationships
- Archive
- Migration

## Service Tests

测试：

- Appointment lifecycle
- Reminder lifecycle
- No-show → follow-up

## UI Tests

在 macOS 环境执行：

- Create Customer
- Create Appointment
- Reschedule
- Mark Arrived
- Search
- Import

---

# 33. Mock / Demo 数据

Debug 模式可以提供 DemoDataSeeder。

要求：

- Release 不自动写 Demo 数据
- Demo 数据可清空
- 测试数据与正式数据库隔离

示例：

```text
王女士
李先生
张女士
赵先生
```

---

# 34. 数据迁移策略

SwiftData schema 从一开始必须考虑版本。

任何模型变更：

- 先评估迁移
- 禁止直接破坏生产数据库
- 测试旧数据升级

在没有迁移验证前，不得宣称升级安全。

---

# 35. 搜索与筛选

SearchService 统一处理。

支持组合：

```text
keyword
status
source
tag
dateRange
```

UI 采用：

- Search Field
- Filter Popover
- Active Filter Chips

避免每页重复写不同搜索逻辑。

---

# 36. 重复客户处理

检测到可能重复：

UI：

```text
Possible duplicate

王女士
138 **** 8888

Existing:
王女士
138 **** 8888
Last contacted: Sep 10
```

操作：

- Use Existing
- Create Anyway
- Merge

Merge 必须：

- 保留 Appointment
- 保留 Activity
- 保留 FollowUp
- 合并 Tags
- 写 customerMerged Activity

---

# 37. 未到店流程

用户点击：

**No Show**

系统：

1. Appointment.status = noShow
2. noShowAt = now
3. Activity 写入
4. Reminder 全部取消
5. 弹出：

```text
Create a follow-up?

Tomorrow 11:00
Custom...
Skip
```

这是核心流程，必须测试。

---

# 38. 改期流程

点击：

**Reschedule**

Sheet：

- 原时间只读
- 新日期
- 新时间
- 原因
- 是否保留默认提醒

提交：

1. 写 AppointmentChange
2. 更新 Appointment
3. 写 Activity
4. 取消旧通知
5. 创建新通知
6. 刷新 Today / Calendar

---

# 39. 到店流程

点击：

**Arrived**

- status = arrived
- arrivedAt = now
- Activity

之后：

- 可点击 Complete

V1 可以允许：

Arrived → Completed

---

# 40. 客户要求与内部备注

必须分离。

```text
customerRequest
internalNote
```

原因：

未来可能：

- 把客户要求发送给团队
- 内部备注不应该共享

---

# 41. 预约冲突

V1 提供轻量提示。

若新预约时间附近存在预约：

```text
There are 3 appointments around this time.
```

不阻止保存。

未来可配置容量。

---

# 42. 平台来源统计

V1 数据层保留。

简单统计：

- 本月新增客户来源
- 本月预约来源
- 到店来源

不要在第一阶段做复杂报表。

---

# 43. Future Account Architecture

V1 不开发登录。

但预留协议：

```text
AuthProvider
SyncProvider
RemoteRepository
```

V1：

```text
AuthProvider = LocalIdentity
SyncProvider = Disabled
```

未来：

```text
AuthProvider = ServerAuth
SyncProvider = CloudSync
```

---

# 44. Future Sync Fields

主模型建议预留：

```text
serverID: String?
syncState
lastSyncedAt
```

但不要因为“未来可能同步”过早增加复杂冲突解决器。

---

# 45. Future Platform Import

未来可能接：

- 广告平台
- 表单
- CRM
- 微信相关业务接口
- CSV 自动监控

统一入口：

```text
LeadImportProvider
```

当前：

```text
CSVImportProvider
PasteImportProvider
```

未来：

```text
RemoteLeadProvider
```

---

# 46. 不在 V1 做的功能

明确延后：

- 多用户
- 团队权限
- 云同步
- iPhone App
- 微信小程序
- 在线支付
- AI 自动销售
- 自动拨号
- 自动群发短信
- 大型 BI
- Web 后台
- 复杂会员系统
- 平台自动抓取

如果 Codex 发现这些需求，不得擅自扩张 Scope。

---

# 47. macOS 构建门禁

任何 Phase 完成前至少满足相应 Gate。

## Build Gate

在 macOS runner：

```text
xcodebuild
```

或当前工程正式构建命令：

- compile success
- no fatal warnings introduced
- unit tests pass

GitHub Actions 可使用 macOS hosted runner。

---

# 48. Windows → macOS 开发执行方案

推荐：

## Lane A —— Windows Codex

负责：

- 源码
- 模型
- Service
- 文档
- 测试
- CI
- Git

## Lane B —— macOS CI

负责：

- 编译
- Swift 测试
- Xcode build gate

## Lane C —— Real Mac

负责：

- UI 真实验收
- Notification
- Permission
- Window behavior
- Keyboard shortcuts
- Accessibility
- Signing
- Packaging

没有 Lane C 时：

项目可以推进到“CI 可构建”，但不能定义为“Release Ready”。

---

# 49. CI 建议

至少：

```text
on:
  push
  pull_request
```

macOS job：

- checkout
- select Xcode
- build
- unit test

后续：

- archive
- artifact

不要一开始加入复杂发布流水线。

---

# 50. Git 规则

每个 Phase 完成：

```text
git status
tests
build gate
commit
```

建议 Commit：

```text
feat(customers): add customer repository and detail flow
feat(appointments): add appointment lifecycle
feat(reminders): schedule local notifications
feat(import): add csv import preview
feat(backup): add local backup restore
```

禁止：

```text
update stuff
fix
changes
```

---

# 51. 分支建议

早期单人：

```text
main
feature/*
fix/*
```

main 必须保持：

- 可构建
- 测试通过

Codex 不得长期在 main 上堆积未验证大改。

---

# 52. Phase 0 —— Repository & Architecture

目标：

建立项目执行基础。

任务：

- README
- docs/
- architecture
- Git
- CI skeleton
- Swift/macOS project scaffold
- directory structure
- coding conventions
- domain enums
- initial model definitions

验收：

- Repo 清晰
- macOS CI 可触发
- 基础 Target 可构建
- 无业务 UI 也可以

---

# 53. Phase 1 —— Local Persistence Foundation

目标：

建立 SwiftData。

实现：

- Customer
- Appointment
- Activity
- FollowUp
- LeadSource
- Tag
- Reminder

Service / Repository 基础。

验收：

- CRUD test
- Relationships test
- App relaunch 数据保留
- 不出现重复 container 初始化

---

# 54. Phase 2 —— Customers

实现：

- Customers page
- Add Customer
- Edit
- Search
- Archive
- Customer Detail
- Activity Timeline
- Duplicate warning

验收：

真实完成：

```text
Create → Relaunch → Search → Edit → Archive
```

---

# 55. Phase 3 —— Appointments

实现：

- Create
- Edit
- Confirm
- Arrived
- Complete
- Cancel
- Reschedule
- No Show

验收：

状态机测试完整。

---

# 56. Phase 4 —— Today

实现：

- Today dashboard
- Upcoming list
- Quick actions
- Counts
- Inspector

验收：

所有状态切换后首页实时正确刷新。

---

# 57. Phase 5 —— Notifications

实现：

- permission
- default presets
- schedule
- reschedule
- cancel
- reconcile

验收：

在真实 Mac：

- 建立 5 分钟后的测试预约
- 成功提醒
- 改时间后旧提醒消失
- 取消后不提醒

---

# 58. Phase 6 —— Follow-up

实现：

- Follow-up page
- create
- complete
- snooze
- no-show integration

验收：

No Show → Create FollowUp → Follow-up Page → Complete

---

# 59. Phase 7 —— Calendar

实现：

- Month
- Date selection
- Daily appointments
- status indicator
- open detail

不要先追求复杂 drag & drop。

---

# 60. Phase 8 —— Inbox & CSV Import

实现：

- CSV select
- preview
- column mapping
- validation
- duplicate detection
- import summary
- ImportBatch

验收：

准备：

- 正常 CSV
- 缺列 CSV
- 重复电话 CSV
- 空值
- Unicode 中文

全部测试。

---

# 61. Phase 9 —— Search & Filters

实现：

- ⌘K
- customer search
- appointment search
- filters
- recent search optional

验收：

1000+ mock 客户仍可流畅查询。

---

# 62. Phase 10 —— Backup / Restore / Export

实现：

- manual backup
- auto backup
- retention
- restore
- CSV export

验收：

建立数据：

```text
100 customers
50 appointments
20 followups
```

备份。

删除/修改部分数据。

恢复。

检查数量和关键关系一致。

---

# 63. Phase 11 —— Visual System

在业务稳定后统一视觉。

实现：

- Design Tokens
- Material / Glass
- Toolbar
- Sidebar
- Inspector
- Empty State
- Loading
- Error State
- Icons

注意：

不要在前期反复重构视觉。

---

# 64. Phase 12 —— QA / Release Candidate

测试：

- 真实日常使用
- 重启
- 系统休眠
- 通知权限拒绝
- 备份失败
- CSV 错误
- 数据量
- 搜索
- 改期
- 未到店
- 归档
- 恢复

版本：

```text
Goosegrass 1.0.0-rc.1
```

---

# 65. Phase 13 —— Release Readiness

只有具备真实 Mac 时执行：

- App icon
- Bundle ID
- Signing
- Notarization
- Archive
- Distribution method
- Release Notes

如果用户暂时仅个人使用：

可以优先完成本机安装包流程。

App Store 是否发布是后续决策。

---

# 66. 每阶段 Codex 输出格式

Codex 每完成一个阶段必须输出：

```text
Phase:
Status:

Completed:
- ...

Files changed:
- ...

Database changes:
- ...

Tests:
- ...

macOS build:
- Passed / Not verified

Risks:
- ...

Manual verification required:
- ...

Git checkpoint:
- <commit>
```

---

# 67. Codex 自主决策权限

Codex 可以自主决定：

- 文件拆分
- 小型重构
- 命名优化
- 测试组织
- ViewModel 内部实现
- SwiftUI 组件拆分

无需每次询问。

---

# 68. 必须暂停询问用户的情况

只有以下情况必须暂停：

1. 需要破坏现有数据。
2. 需要改变核心技术栈。
3. 需要付费第三方服务。
4. 需要真实 Apple Developer 账号凭据。
5. 需要改变产品关键行为。
6. 发现安全风险。
7. 需要删除大量用户数据。
8. 两种方案会明显影响未来架构且无法安全默认。

普通 UI 微调不要频繁打断。

---

# 69. Codex 禁止事项

禁止：

- 为了“快速完成”把数据只存在内存。
- 把所有逻辑写一个 View。
- View 直接大量操作 SwiftData。
- 未测试迁移就修改 Schema。
- 删除客户导致历史消失。
- 改期覆盖历史。
- 取消预约后保留旧提醒。
- 在日志里记录完整客户隐私。
- 没有 Mac 验证却宣称 Release Ready。
- 因 Windows 环境改成 Electron。
- 大量增加第三方依赖。
- 自行添加云服务器。

---

# 70. 性能目标

V1 最低实际测试：

```text
Customers:     10,000
Appointments:  20,000
Activities:    100,000
```

关键体验：

- 打开 Customers 不应一次渲染全部数据。
- 搜索使用合理 predicate/index。
- Timeline 分页或限制。
- 日历按日期查询。

实际性能以 Mac 测试为准。

---

# 71. Accessibility

至少：

- 不只用颜色表达状态
- VoiceOver label
- Keyboard navigation
- Dynamic text 避免截断关键字段
- 足够对比度

---

# 72. 时间与时区

预约时间必须使用 Date 存储。

显示使用系统 Locale。

V1 是单机本地业务：

- 默认当前系统时区
- 不过早增加多时区复杂度

若未来云同步再定义服务端时间策略。

---

# 73. 数据日期字段

必须统一命名：

```text
createdAt
updatedAt
startAt
endAt
dueAt
arrivedAt
completedAt
cancelledAt
```

避免：

```text
date1
time
create_time
```

混用。

---

# 74. 预约验证

保存前：

- Customer required
- startAt required
- partySize >= 1
- status 合法
- 电话根据客户规则验证

不可阻止过去时间预约，因为可能需要补录历史。

但需要提示。

---

# 75. 数据关系删除规则

Customer Archive：

不删除任何关系。

Appointment Cancel：

不删除 Activity。

FollowUp Delete：

优先 cancel。

真正物理删除必须明确实现并测试关系影响。

---

# 76. 导入失败策略

单行失败不得让整个导入失败。

结果：

```text
Imported: 95
Duplicates: 3
Failed: 2
```

用户可以查看失败行。

---

# 77. App 启动

流程：

```text
Launch
↓
Open Data Store
↓
Run lightweight consistency checks
↓
Reminder reconcile
↓
Load Today
```

不要每次启动执行耗时全库扫描。

---

# 78. First Run

首次启动：

```text
Welcome to Goosegrass
```

只介绍：

1. 本地存储。
2. 添加客户。
3. 创建预约。
4. 提醒功能。

不要做 10 页 onboarding。

---

# 79. 软件命名

正式 UI：

**Goosegrass**

代码：

```text
Goosegrass
```

Bundle 建议未来：

```text
com.<organization>.goosegrass
```

组织标识待用户确定。

禁止 Codex 随便写死最终 Bundle ID。

---

# 80. App Icon

V1 后期再设计。

视觉方向：

- 简洁
- 有辨识度
- 不直接使用复杂鹅图案也可以
- Goosegrass 本身是植物名，可考虑抽象草叶 / G 字形

不要拖慢业务实现。

---

# 81. 版本策略

使用：

```text
0.1.0
0.2.0
...
1.0.0-rc.1
1.0.0
```

---

# 82. Definition of Done —— Feature

一个 Feature 完成必须：

- 业务逻辑实现
- 数据持久化
- 错误处理
- 空状态
- 测试
- 无明显隐私泄漏
- 文档更新
- macOS Build Gate 通过（若环境具备）

---

# 83. Definition of Done —— V1

V1 可称为可用产品，必须：

- 客户 CRUD
- 客户搜索
- 客户去重提示
- 客户 Timeline
- 预约 CRUD
- 状态机
- 改期历史
- 到店
- 未到店
- 取消
- 本地提醒
- Follow-up
- Calendar
- Today
- Inbox
- CSV Import
- Backup
- Restore
- Export
- macOS 原生 UI
- macOS Build 通过
- 真实 Mac 通知验证
- 真实数据 RC 测试

---

# 84. 非功能验收

必须确保：

## Reliability

App crash 后不损坏数据。

## Offline

无网络完全可用。

## Privacy

无隐式上传。

## Recoverability

可备份恢复。

## Traceability

关键业务历史可追踪。

## Maintainability

UI 不直连复杂数据逻辑。

---

# 85. 用户最关键的 5 个场景

最终 RC 必须重复测试：

### Scenario A

推广平台来了 50 个客户。

→ CSV 导入  
→ 检测重复  
→ 新客户进入 Inbox

### Scenario B

客户电话预约。

→ ⌘N  
→ 搜索客户  
→ 创建预约  
→ 提醒

### Scenario C

客户改时间。

→ Reschedule  
→ 历史保留  
→ 旧提醒取消  
→ 新提醒创建

### Scenario D

客户没来。

→ No Show  
→ 创建 Follow-up  
→ 第二天提醒再次联系

### Scenario E

半年后搜索客户。

→ 输入电话尾号  
→ 找到客户  
→ 查看全部预约和跟进历史

---

# 86. 建议首个工程里程碑

Codex 首次正式执行时，不要直接实现所有页面。

先完成：

```text
Milestone 1
Architecture + Build Gate + SwiftData + Customer + Appointment
```

成功条件：

- macOS CI 能编译。
- Customer 可持久化。
- Appointment 可持久化。
- Customer → Appointment 关系正确。
- 单元测试存在。

然后继续 Phase 2。

---

# 87. 项目文档目录

建议：

```text
docs/
├── PRODUCT.md
├── ARCHITECTURE.md
├── DATA_MODEL.md
├── UX.md
├── ROADMAP.md
├── TESTING.md
├── WINDOWS_MACOS_WORKFLOW.md
└── CHANGELOG.md
```

本文件作为总规范：

```text
docs/GOOSEGRASS_MASTER_SPEC.md
```

Codex 后续可以把内容拆分，但不得丢失总规范。

---

# 88. 需求变更机制

任何新需求先归类：

```text
Must
Should
Could
Later
```

再进入 Roadmap。

不要发现新想法就立刻插入正在开发的 Phase。

---

# 89. Future V2

未来可能：

- Account
- Server API
- Cloud Sync
- iPhone companion
- Team
- Role permissions
- shared calendar
- automatic platform imports
- AI lead parser
- natural language search

但 V1 不依赖任何 V2 能力。

---

# 90. 最终产品体验标准

Goosegrass 最终不应像传统复杂 CRM。

它应该更接近：

```text
Calendar
+
Contacts
+
Reminders
+
Lightweight CRM
```

用户打开 App 后应立即回答：

1. 今天谁会来？
2. 下一个客户是谁？
3. 还有谁没有联系？
4. 谁没有按约到店？
5. 谁需要再次跟进？

如果 Goosegrass 能稳定回答这 5 个问题，就走在正确方向。

---

# 91. Codex 初始执行指令

可将下面内容直接发送给 Codex：

```text
你现在负责 Goosegrass 项目。

请先完整阅读 docs/GOOSEGRASS_MASTER_SPEC.md，把它作为项目最高优先级产品与工程规范。

当前开发者主机是 Windows，但产品目标是原生 macOS App。不得因此修改为 Electron、Web、Flutter、Qt 或其他跨平台方案。

技术方向固定：
Swift + SwiftUI + SwiftData + UserNotifications。

你的目标不是快速生成 Demo，而是逐步交付真实可用的本地客户预约管理 App。

执行规则：

1. 先检查当前仓库状态。
2. 根据 Master Spec 判断当前处于哪个 Phase。
3. 每次只推进一个清晰可验收的 Phase / Step。
4. 保持数据结构、Repository、Service、UI 分层。
5. 关键业务逻辑必须有测试。
6. 不允许破坏预约历史。
7. 不允许因为 Windows 缺少 Xcode 就声称 macOS 已验证。
8. 配置 macOS CI Build Gate。
9. 每阶段完成后运行能运行的测试。
10. macOS 构建必须以 CI / Mac 实际结果为准。
11. 每阶段完成建立 Git checkpoint。
12. 只有遇到数据破坏风险、核心架构冲突、安全风险、付费服务或必须由用户提供 Apple 凭据时才暂停询问。

现在先执行 Phase 0：
Repository & Architecture。

完成后输出：
- 完成项
- 修改文件
- 测试结果
- macOS Build Gate 状态
- 风险
- 需要真实 Mac 验证的内容
- Git checkpoint
- 下一步建议
```

---

# 92. Windows 用户的现实准备清单

开发早期：

- Windows
- Git
- GitHub
- Codex
- 代码仓库

即可开始。

进入 macOS UI / Notification / Release 阶段之前，需要至少一种 macOS 环境：

### 推荐优先级

1. 自有 Mac / Mac mini
2. 可远程访问的 Mac
3. 企业/云 Mac
4. GitHub Actions macOS Runner 作为 Build/Test Gate

注意：

GitHub Actions 可以承担大量编译和测试，但它不能完全替代真实交互式 Mac 的最终 UX 验收。

---

# 93. 官方技术依据

项目实现阶段优先参考 Apple 官方文档：

- Xcode SDK and system requirements
- SwiftData
- UserNotifications
- SwiftUI

以及 GitHub 官方 macOS hosted runner 文档。

技术版本可能随时间变化，因此 Codex 在升级 Xcode / Swift / macOS SDK 前应重新检查官方兼容信息。

---

# 94. 当前最终决策摘要

```text
Product:
Goosegrass

Platform:
macOS

Developer Host:
Windows

Architecture:
Native macOS
Swift
SwiftUI
SwiftData
UserNotifications
Repository + Service

Storage:
Local First

Account:
Not in V1
Interface reserved

Cloud:
Not in V1
Interface reserved

Core:
Customer
Appointment
Reminder
Follow-up
Inbox
Calendar
History
Import
Backup

UI:
Apple native
Glass / Material
Sidebar + Content + Inspector

Execution:
Windows coding
macOS CI build
Real Mac final QA
```

---

# 95. 最重要的工程纪律

> Goosegrass 的价值不是“能创建一条预约”。

它真正的价值是：

> **半年以后仍然能够可靠地告诉用户：这个客户是谁、从哪里来、什么时候联系过、约过几次、改过几次、有没有来、下一步该做什么。**

因此：

**数据历史、提醒可靠性、客户去重、跟进闭环、备份恢复，是 Goosegrass 的核心竞争力。**

---

文档版本：**v1.0**  
文档状态：**Codex Execution Baseline**  
产品：**Goosegrass**  
