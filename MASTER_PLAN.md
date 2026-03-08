# HouseFriend — Master Plan

> **一句话定位：** 湾区版"邻里体检报告"——在地图上叠加 10 层真实数据，帮用户在买房/租房前看清一个街区的安全、环境、学区、噪音全貌。
>
> 对标产品：App Store「Neighborhood Check」(id6446656055)

---

## 目录
1. [产品愿景](#1-产品愿景)
2. [技术架构](#2-技术架构)
3. [10 大数据图层](#3-10-大数据图层)
4. [已完成功能](#4-已完成功能)
5. [待完成功能](#5-待完成功能)
6. [已知问题 & Rules](#6-已知问题--rules)
7. [数据覆盖范围](#7-数据覆盖范围)
8. [文件结构](#8-文件结构)

---

## 1. 产品愿景

### 核心用户场景
- 想在湾区买房/租房的用户，打开 app → 搜索地址 → 立即看到该区域的综合安全评分
- 关心孩子上学的家长，切换到学区图层查看附近学校评级
- 对噪音/空气敏感的用户，切换对应图层直观感受

### 设计原则
- **地图优先**：所有数据用颜色叠加在地图上，不用表格
- **一键评分**：搜索地址后底部弹出「Neighborhood Report」，给出 A/B/C/D/F 评级
- **覆盖完整**：数据覆盖整个旧金山湾区 9 县，不仅限于硅谷
- **按需加载**：只有用户切换到某个图层时，才加载该图层的数据；不预先加载所有图层，节省流量和内存

---

## 2. 技术架构

| 层级 | 技术选型 | 说明 |
|------|---------|------|
| 框架 | SwiftUI + MapKit (iOS 17+) | 原生，无第三方地图依赖 |
| 地图叠加 | `MapPolygon` / `MapPolyline` / `UIViewRepresentable` | 按图层类型选择 |
| 热力图渲染 | `CrimeHeatmapOverlay` (CGContext 像素渲染) | 避免方块感，平滑过渡 |
| 路网数据 | OpenStreetMap Overpass API（实时拉取） | 噪音图层，无需 API Key |
| 空气质量 | Open-Meteo API（免费，无 Key） | 返回真实 us_aqi |
| 地震数据 | USGS Earthquake API | M≥2.5，实时 |
| 学校数据 | 硬编码 130+ 所，按县分类 | 含评级、类型 |
| 地址搜索 | `MKLocalSearchCompleter` + `MKLocalSearch` | 模糊补全，偏向湾区 |
| 定位 | `CLLocationManager` | 当前位置 → 自动分析 |
| 构建 | Xcode 16，`PBXFileSystemSynchronizedRootGroup` | 新文件自动加入 target |

### 项目路径
```
~/Documents/openclaw_projects/HouseFriend/
├── HouseFriend/
│   ├── Models/          # 数据模型
│   ├── Services/        # 数据获取服务
│   └── Views/           # UI 组件
└── MASTER_PLAN.md       # 本文件
```

---

## 3. 10 大数据图层

| # | 图层 | 渲染方式 | 数据来源 | 覆盖状态 |
|---|------|---------|---------|---------|
| 1 | 🔴 Crime 犯罪率 | CGContext 热力图（像素渲染） | 硬编码 Gaussian 模型 + Details 模式 | ✅ 全湾区 |
| 2 | 🔊 Noise 噪音 | MapPolyline（每条路） | OSM Overpass API 实时拉取 | ✅ 实时动态 |
| 3 | 🏫 Schools 学校 | MapAnnotation 图钉 | 硬编码 130+ 所 | ✅ 全湾区 9 县 |
| 4 | ☢️ Superfund 超级基金 | MapAnnotation 图钉 | 硬编码 62 处 | ✅ 全湾区 |
| 5 | 🌋 Earthquake 地震 | MapCircle（按震级缩放） | USGS 实时 API | ✅ 实时 |
| 6 | 🔥 Fire Hazard 火灾 | MapPolygon | 硬编码 22 区 CAL FIRE | ✅ 全湾区 |
| 7 | ⚡ Electric Lines 电力线 | MapPolyline | 硬编码 PG&E 输电走廊 | ⚠️ 仅主干 |
| 8 | 🏠 Supportive Housing 保障房 | MapAnnotation 图钉 | 硬编码 | ⚠️ 覆盖偏少 |
| 9 | 💨 Air Quality/Odor 空气/气味 | MapPolygon | Open-Meteo API + 硬编码工业区 | ✅ |
| 10 | 👥 Population 人口 | ZIP 区号多边形 + 点击高亮 + 人口统计滑动面板 | 硬编码 2020 Census ZIP 数据 | 🔄 重构中 |

---

## 4. 已完成功能

### UI
- [x] 右侧竖向 Sidebar（10 个图层切换按钮）
- [x] 顶部地址搜索栏（`MKLocalSearchCompleter` 模糊补全）
- [x] 底部 Neighborhood Report 面板（Pin 地址后展开）
- [x] 评分卡片（进度环 + A/B/C/D/F 字母评级）
- [x] 图例（Legend）显示在左下角
- [x] 缩放 +/- 按钮（右下角）
- [x] 当前位置按钮
- [x] 激活图层标签（地图顶部 chip）

### 地图图层
- [x] Crime：CGContext 像素热力图（无方块，平滑渐变）
- [x] Crime Details 开关：缩放后显示具体事件标注
- [x] Noise：Overpass API 动态拉取每条路，按道路类型着色
- [x] Schools：130+ 所，点击显示详情 Sheet
- [x] Superfund：62 处，点击显示详情
- [x] Earthquake：USGS 实时，圆圈大小 = 震级
- [x] Fire Hazard：22 个 CAL FIRE 区域
- [x] Electric Lines、Supportive Housing、Air Quality、Population

### 数据
- [x] 湾区全 9 县覆盖（Santa Clara, Alameda, SF, San Mateo, Contra Costa, Marin, Sonoma, Napa, Solano）
- [x] 地图默认视图：center (37.650, -122.150)，span 0.85 显示整个湾区

---

## 5. 待完成功能

### 高优先级
- [ ] **Noise 图层 UI**：加载中显示 spinner，Overpass 失败时 fallback 到硬编码数据
- [ ] **Supportive Housing 扩充**：SF、Oakland、Berkeley、San Mateo 的保障房数据
- [ ] **Electric Lines 扩充**：加入 115kV 以下配电线路

### 中优先级
- [ ] **Crime Details 真实数据**：接入 SF Open Data、Oakland Crime API 替换 mock 数据
- [ ] **学校评级数据**：接入 GreatSchools API 或 CA School Dashboard 数据
- [ ] **Neighborhood Report 优化**：每个图层给出具体文字描述（不只是分数）
- [ ] **历史对比**：同一地址犯罪率/空气质量的年度趋势

### 低优先级
- [ ] **深色模式**适配
- [ ] **iPad 布局**优化
- [ ] **分享功能**：截图 + 评分卡生成图片分享
- [ ] **收藏地址**：保存常用地址

---

## 6. 已知问题 & Rules

> 每次修完 Bug，必须在这里记录教训（Lazar 工作流）

### 🐛 已修复的坑

**R001 - CGImage premultiplied alpha**
- 问题：用 `CGImageAlphaInfo.premultipliedLast` 时，不预乘 RGB 值会导致颜色溢出成白色
- 教训：热力图渲染用 `CGContext.setFillColor + fill()` 更安全，避免手动管理字节格式
- 文件：`CrimeHeatmapOverlay.swift`

**R002 - SwiftUI .overlay() 位置**
- 问题：`.overlay()` 加在最外层 ZStack 上会覆盖所有 UI（sidebar、搜索栏）
- 教训：UIKit overlay 必须放在 ZStack 内部、`mapLayer` 正下方，加 `.allowsHitTesting(false)`
- 文件：`ContentView.swift`

**R003 - Xcode PBXFileSystemSynchronizedRootGroup**
- 问题：新建 Swift 文件后不需要手动加入 pbxproj，Xcode 16 自动同步
- 教训：只需把文件放到正确目录即可，不用 `sed` 修改 project 文件

**R004 - Shell heredoc 中的 `$0`**
- 问题：bash heredoc 里 `$0` 会被 shell 展开
- 教训：包含 `$` 的字符串用 Python 脚本通过 `scp` 上传再执行，不要用 heredoc

**R005 - Sidebar 按钮被截断**
- 问题：10 个按钮超出屏幕，底部按钮不可见
- 教训：Sidebar 必须用 `ScrollView`，`maxHeight` 设 380，`pinnedLocation != nil` 时增加底部 spacer

**R006 - MKLocalSearch 模糊度不足**
- 问题：`MKLocalSearch` 需输入大部分关键词才有结果
- 教训：用 `MKLocalSearchCompleter` 做实时补全，1 个字符就能出结果；`MKLocalSearch` 只做最终坐标解析

**R007 - Gaussian 衰减参数单位**
- 问题：犯罪热力图 k 值用度(°)做单位，衰减半径高达 15 英里，导致全图变红
- 教训：Gaussian 衰减必须用英里做单位：`exp(-distMiles² / radius²)`，半径建议 2-5 英里

### ⚠️ 当前已知限制

- Overpass API 在 Mac 本地测试超时（504），但 iOS 设备直连正常
- Crime 热力图是 Gaussian 模型估算，非真实逐街道犯罪数据
- 学校评分为静态硬编码，非实时 API

---

## 7. 数据覆盖范围

### 湾区 9 县覆盖状态

| 县 | 学校 | 犯罪 | 火灾 | 人口 |
|----|------|------|------|------|
| Santa Clara | ✅ 36 所 | ✅ | ✅ | ✅ 14 城 |
| Alameda | ✅ 29 所 | ✅ | ✅ | ✅ 12 城 |
| San Francisco | ✅ 13 所 | ✅ | ✅ | ✅ |
| San Mateo | ✅ 16 所 | ✅ | ✅ | ✅ 15 城 |
| Contra Costa | ✅ 17 所 | ✅ | ✅ | ✅ 12 城 |
| Marin | ✅ 8 所 | ✅ | ✅ | ✅ 7 城 |
| Sonoma | ✅ 5 所 | ⚠️ 少 | ✅ | ✅ 5 城 |
| Napa | ⚠️ 少 | ⚠️ 少 | ⚠️ 少 | ✅ 2 城 |
| Solano | ⚠️ 少 | ✅ Vallejo | ⚠️ 少 | ✅ 4 城 |

---

## 8. 文件结构

```
HouseFriend/
├── Models/
│   ├── Category.swift          # CategoryType enum, NeighborhoodCategory
│   ├── CrimeMarker.swift       # CrimeMarker, CrimeType (Details 模式用)
│   ├── MapZone.swift           # MapZone (polygon + value)
│   └── ...
├── Services/
│   ├── AirQualityService.swift     # Open-Meteo API
│   ├── CrimeService.swift          # SF Open Data + mock
│   ├── EarthquakeService.swift     # USGS API
│   ├── ElectricLinesService.swift  # 硬编码 PG&E 走廊
│   ├── FireDataService.swift       # 硬编码 CAL FIRE 22 区
│   ├── LocationService.swift       # CLLocationManager
│   ├── NoiseService.swift          # Overpass API 动态拉取
│   ├── PopulationService.swift     # 硬编码 65 城市
│   ├── SchoolService.swift         # 硬编码 130+ 学校
│   ├── SearchCompleterService.swift # MKLocalSearchCompleter
│   ├── SuperfundService.swift      # 硬编码 62 处
│   └── SupportiveHousingService.swift
├── Views/
│   ├── ContentView.swift           # 主界面（地图 + 所有图层）
│   ├── CategoryCardView.swift      # 底部评分卡片
│   ├── CrimeHeatmapOverlay.swift   # CGContext 犯罪热力图
│   ├── CrimeMarkerView.swift       # Details 模式标注
│   ├── DetailSheetView.swift       # School/Superfund/Housing 详情
│   └── LegendView.swift            # 图例
└── Assets.xcassets/
```

---

---

## 9. 功能效果规格（Feature Spec）

> 本章描述每个功能的**预期视觉效果、交互行为、数据呈现方式**，作为开发和验收的标准。

---

### 9.0 Population 人口图层（重点功能）

**视觉效果**
- 地图上显示各 ZIP Code 区号标签（如「94301」），字体 caption，灰色，随缩放显示/隐藏
- 每个 ZIP 区域用细边框多边形勾勒出边界（边框颜色浅灰，填充透明）
- 未选中状态：多边形透明，只显示 ZIP 号码标签

**点击交互**
- 点击某个 ZIP 区域 → 该区域高亮（填充浅蓝色半透明）
- 同时从底部弹出人口统计滑动面板（可上下拖拽展开/收起）

**人口统计滑动面板（Demographics Sheet）包含 3 部分：**

1. **人种分布（Race / Ethnicity）**
   - 横向堆叠色条（Stacked Bar），全宽 = 100%
   - 颜色：White=蓝、Hispanic=橙、Asian=绿、Black=紫、Other=灰
   - 每段显示百分比数字
   - 下方图例说明各颜色对应人种

2. **家庭收入分布（Household Income）**
   - 纵向柱状图，6 个收入区间：<$25k / $25-50k / $50-75k / $75-100k / $100-150k / $150k+
   - 柱子颜色：低收入→红，中收入→橙，高收入→绿
   - 每柱显示百分比
   - 底部显示该 ZIP 的中位家庭收入（Median Household Income）

3. **年龄分布（Age Distribution）**
   - 横向条形图，5 个年龄组：0-17 / 18-34 / 35-54 / 55-64 / 65+
   - 统一蓝色系，颜色深浅区分年龄段
   - 每条显示百分比和人口数（估算）
   - 底部显示中位年龄（Median Age）

**数据来源**：2020 US Census（硬编码约 40 个主要湾区 ZIP Code）

---

### 9.1 地图主界面

**视觉效果**
- 默认打开显示整个旧金山湾区，从 Vallejo（北）到 San Jose（南），Pacifica（西）到 Antioch（东）
- 地图底图使用 Apple Maps 标准样式，城市名、道路名清晰可读
- 当前激活图层的彩色叠加层覆盖在地图上，透明度约 55-70%，底图始终透得出来
- 右侧竖向 Sidebar 始终可见，不遮挡地图主体内容

**交互**
- 双指捏合缩放地图，+/- 按钮也可缩放
- 单指拖动平移地图，图层叠加随地图实时移动
- 切换图层后，叠加层立即更新，无闪烁

---

### 9.2 Crime 犯罪率图层

**视觉效果（目标）**
- 全地图无空白区域，每一块陆地都有颜色
- 颜色从深红→橙红→橙色→琥珀→浅琥珀，连续平滑过渡，无方块边界感
- 高犯罪区（West Oakland、Richmond、SF Tenderloin）显示深红色，肉眼清晰可辨
- 安全郊区（Palo Alto、Saratoga、Orinda）显示浅琥珀/米色，与高犯罪区对比明显
- 海湾水域不着色（显示 Apple Maps 蓝色底图）

**颜色规格**
| 犯罪等级 | 颜色 | RGB |
|---------|------|-----|
| 极高 (>0.72) | 深红 | (191, 13, 13) |
| 高 (0.55-0.72) | 橙红 | (235, 64, 20) |
| 中高 (0.40-0.55) | 橙色 | (250, 133, 38) |
| 中 (0.28-0.40) | 琥珀 | (254, 184, 89) |
| 低 (0.18-0.28) | 浅琥珀 | (255, 219, 153) |
| 极低 (<0.18) | 米色 | (255, 238, 200) |

**Details 模式（右上角开关打开后）**
- 缩放到街道级别（span < 0.08°）后，地图上出现具体犯罪事件标注
- 🟣 紫色星形 = 暴力犯罪（抢劫、伤人）
- 🔵 青色方块 = 财产犯罪（盗窃、入室）
- 🟠 橙色 = 车辆盗窃/破窗
- 圆圈+数字 = 同区域多起案件聚合显示
- 高犯罪区标注密度明显多于低犯罪区
- 随地图平移/缩放自动刷新

---

### 9.3 Noise 噪音图层

**视觉效果（目标）**
- 每一条道路都有颜色线段，颜色代表噪音等级
- 高速公路（I-880、US-101）显示粗紫色线，住宅街道显示细绿色线
- 缩放到街道级别可以看到每一条小路的噪音颜色
- 道路颜色线段紧贴实际道路走向，不是模糊色块

**颜色 & 线宽规格**
| 道路类型 | 噪音 | 颜色 | 线宽 |
|---------|------|------|------|
| motorway（高速） | 78dB | 紫色 | 5px |
| trunk（主干道） | 74dB | 红紫 | 4px |
| primary（一级路） | 68dB | 橙红 | 3.5px |
| secondary（二级路） | 63dB | 橙色 | 3px |
| tertiary（三级路） | 58dB | 黄色 | 2.5px |
| residential（住宅街） | 52dB | 黄绿 | 2px |
| service（小路） | 47dB | 绿色 | 1.5px |

**加载状态**
- 切换图层或平移地图后，左下角图例区域显示「Loading road data...」+ spinner
- 加载完成后显示「X roads loaded」
- 地图视野过大时（span > 1.2°）显示「Zoom in to see street noise」提示

---

### 9.4 Schools 学校图层

**视觉效果**
- 地图上显示彩色图钉，颜色区分学校类型
  - 🟢 绿色 = 小学（Elementary）
  - 🔵 蓝色 = 初中（Middle）
  - 🟣 紫色 = 高中（High School）
- 图钉上方显示学校名称（字体 caption 级别）
- 缩放较远时图钉聚合，避免密集遮挡

**点击学校图钉后（Detail Sheet）**
- 从底部弹出详情卡，显示：
  - 学校名称、类型
  - GreatSchools 评分（1-10 分，星级显示）
  - 学生人数、学区名称
  - 距离 Pin 地址的步行/驾车时间
  - 「在地图中查看」按钮

---

### 9.5 Superfund 超级基金污染场地

**视觉效果**
- 地图上显示橙色/红色警告图标（⚠️ 或骷髅头形状）
- 每个图标旁边显示场地名称
- 污染等级高的场地图标更大、颜色更深

**点击后 Detail Sheet**
- 场地名称、污染类型（重金属/化学物/放射性等）
- EPA 危险等级（NPL 优先级）
- 与 Pin 地址的距离
- 简短描述（该场地的历史污染背景）

---

### 9.6 Earthquake 地震图层

**视觉效果**
- 过去 30 天内 M≥2.5 的地震显示为半透明圆圈
- 圆圈大小与震级成正比（M3.0 小圆，M6.0 大圆）
- 颜色从黄色（小震）→橙色→红色（大震）
- 圆圈带脉冲动画效果（最近 7 天的地震有扩散波动效果）

**点击后**
- 显示震级、时间、震源深度、震中地名

---

### 9.7 Fire Hazard 火灾风险图层

**视觉效果**
- CAL FIRE 标准分级：Extreme（极高）/ Very High / High / Moderate
- 颜色：深红→橙红→橙→黄
- 多边形边界清晰，填充半透明
- 山区、林区（Oakland Hills、Marin、Santa Cruz Mountains）显示明显红色

**图例**
- 🔴 Extreme — 极高危险（1991 Oakland Tunnel Fire 区域等）
- 🟠 Very High — 非常高
- 🟡 High — 高
- 🟢 Moderate — 中等

---

### 9.8 地址搜索

**交互效果**
- 搜索框输入第 1 个字符即开始出现补全建议
- 下拉列表分两层：
  - 上方：🔵 蓝色图标 = 实时模糊补全建议（极快，<200ms）
  - 下方：🔴 红色图标 = 完整搜索结果（含精确坐标）
- 点击任一建议 → 地图立即飞到该地址，缩放到街区级别（span ≈ 0.03°）
- 地图中心出现红色 📍 Pin，底部面板展开显示 Neighborhood Report

**搜索结果偏向**
- 优先显示湾区内结果（2° 半径区域过滤）
- 支持：门牌地址、POI（咖啡店、公司）、城市名、邮编

---

### 9.9 Neighborhood Report 底部面板

**触发方式**
- 地图上点击 Pin / 搜索地址后自动展开
- 也可手动向上拖拽展开

**视觉效果**
- 白色卡片从底部弹出，圆角顶边
- 顶部显示：Pin 地址全称 + 字母评级徽章（A/B/C/D/F，绿/蓝/橙/红）
- 横向滚动的评分卡片，每张卡片包含：
  - 图层名称 + 图标
  - 进度环（0-100 分）
  - 颜色（绿=好/红=差）
  - 子评分描述（如「Crime: Low — 较安全区域」）

**评分逻辑**
| 图层 | 满分 = 最好 | 说明 |
|------|-----------|------|
| Crime | 低犯罪 = 高分 | 基于 Gaussian 热力值反转 |
| Schools | 附近有高评分学校 = 高分 | 最近 3 所学校平均评分 |
| Noise | 低 dB = 高分 | Overpass 路网类型加权 |
| Earthquake | 距活断层远 = 高分 | 距 Hayward/San Andreas 距离 |
| Fire | 非 Extreme/Very High 区 = 高分 | CAL FIRE 分级映射 |
| Superfund | 附近无污染场地 = 高分 | 1 英里内场地数量 |
| Air Quality | AQI 低 = 高分 | Open-Meteo 实时数据 |
| Population | 中等密度 = 高分 | 过密/过疏都扣分 |

---

### 9.10 性能 & 流量规格

**按需加载原则（Lazy Loading）**
- App 启动时只请求定位权限，**不加载任何图层数据**
- 用户切换到某个图层时，才触发该图层的数据加载
- 切换回已加载过的图层时，优先使用缓存，不重复请求网络

**各图层加载策略**

| 图层 | 加载时机 | 缓存策略 |
|------|---------|---------|
| Crime 犯罪热力图 | 切换到 Crime tab 时，后台线程计算 Gaussian 网格 | 永久缓存（纯计算，不联网） |
| Noise 噪音 | 切换到 Noise tab 时拉取 Overpass API | 地图移动超过 50% 视野时刷新 |
| Schools 学校 | 切换到 Schools tab 时加载 | 永久缓存（硬编码数据） |
| Earthquake 地震 | 切换到 Earthquake tab 时请求 USGS | Session 内缓存 30 分钟 |
| Fire Hazard 火灾 | 切换到 Fire tab 时加载 | 永久缓存（硬编码数据） |
| Superfund | 切换到 Superfund tab 时加载 | 永久缓存（硬编码数据） |
| Air Quality | 切换到 Air tab 时请求 Open-Meteo | Session 内缓存 1 小时 |
| Electric Lines | 切换到 Electric tab 时加载 | 永久缓存（硬编码数据） |
| Supportive Housing | 切换到 Housing tab 时加载 | 永久缓存（硬编码数据） |
| Population | 切换到 Population tab 时加载 | 永久缓存（硬编码数据） |

**加载动画规格**
- 切换图层时，如果数据尚未就绪，地图中央显示旋转 Loading 动画（`ProgressView` 样式）
- Loading 动画带半透明黑色背景圆角卡片，不遮挡整个地图，居中偏上显示
- 卡片内容：🔄 spinner + 图层名称（如「Loading Earthquake data...」）
- 数据加载完成后动画自动消失，无需用户操作
- 硬编码数据（Schools、Fire 等）加载极快，Loading 动画持续 < 0.3s，几乎感知不到
- 网络请求（Overpass、USGS）可能需要 1-3s，Loading 动画明显可见

**实现方式**
- 每个 Service 增加 `isLoaded: Bool` 标志，已加载则跳过
- Sidebar 按钮切换时触发 `loadIfNeeded()` 而非 `fetch()`
- 网络请求类 Service（Overpass、USGS、Open-Meteo）加入 30 分钟 TTL 缓存
- ContentView 增加 `@State var isLayerLoading: Bool`，切换时设为 true，数据到位后设为 false
- Loading 卡片作为 ZStack 最顶层 overlay，`isLayerLoading == true` 时显示

---

### 9.11 整体 UX 流程（完整用户旅程）

```
打开 app
  ↓
看到整个湾区地图（Crime 层默认开启，热力图可见）
  ↓
搜索「1234 Main St, Sunnyvale」
  ↓
地图飞到 Sunnyvale，Pin 落下，底部 Neighborhood Report 展开
  ↓
看到总评分：B+（橙色）
  ↓
横划评分卡：Crime 85/100 ✅  Schools 72/100 ✅  Noise 61/100 ⚠️
  ↓
点击 Noise 卡片 → 切换到噪音图层，地图显示附近道路颜色
  ↓
发现旁边 US-101 是紫色（高噪音），决定往内街找房子
  ↓
切换 Schools 图层 → 看到 0.5 英里内有绿色图钉（好学区小学）
  ↓
点击学校图钉 → 详情 Sheet 显示评分 9/10
  ↓
心满意足，截图分享给家人
```

---

*最后更新：2026-03-08 | GitHub: ustcwhc/HouseFriend*
