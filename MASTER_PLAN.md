# HouseFriend — Master Plan

> **一句话定位：** 湾区版"邻里体检报告"——在地图上叠加 10 层真实数据，帮用户在买房/租房前看清一个街区的安全、环境、学区、噪音全貌。
>
> 对标产品：App Store「Neighborhood Check」(id6446656055)
>
> **最新 commit：** `6278fa7` | GitHub: ustcwhc/HouseFriend | 最后更新：2026-03-09

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
9. [功能效果规格](#9-功能效果规格feature-spec)

---

## 1. 产品愿景

### 核心用户场景
- 想在湾区买房/租房的用户，打开 app → 搜索地址 → 立即看到该区域的综合安全评分
- 关心孩子上学的家长，切换到学区图层查看附近学校评级
- 对噪音/空气敏感的用户，切换对应图层直观感受

### 设计原则
- **地图优先**：所有数据用颜色叠加在地图上，不用表格
- **一键评分**：长按地址后底部弹出「Neighborhood Report」，给出 A/B/C/D/F 评级
- **覆盖完整**：数据覆盖整个旧金山湾区 9 县，不仅限于硅谷
- **按需加载**：只有用户切换到某个图层时，才加载该图层的数据
- **丝滑体验**：任何操作都不能有卡顿感，始终保持 60fps

### 性能红线（不可妥协）

| 操作 | 要求 |
|------|------|
| 地图平移 / 缩放 | 始终 60fps，无掉帧 |
| 图层切换动画 | < 16ms 响应，数据加载异步进行，不阻塞 UI |
| 底部面板弹出 | < 200ms，弹出动画顺滑 |
| 搜索补全建议 | 输入后 < 150ms 出现 |
| 地图飞行定位 | 流畅动画，无跳帧 |
| 犯罪热力图渲染 | 后台线程计算，主线程只做绘制 |
| ZIP 区域点击高亮 | 即时响应（< 50ms） |

### 性能实现规范

1. **主线程只做 UI**：所有数据计算必须在 `DispatchQueue.global` 或 `Task { }` 中执行
2. **MapPolygon 数量控制**：同一时刻地图上 MapPolygon 数量不超过 200 个
3. **避免 ForEach 重建**：用稳定 `id:` 标识符，避免 SwiftUI 不必要的视图重建
4. **图片 / 渲染缓存**：CGImage 热力图只在 region 变化超过 20% 时重绘
5. **网络请求防抖**：Overpass 等网络请求加 0.5s debounce，避免拖拽时频繁触发

---

## 2. 技术架构

| 层级 | 技术选型 | 说明 |
|------|---------|------|
| 框架 | SwiftUI + UIKit MapKit (iOS 17+) | UIViewRepresentable 包装 MKMapView |
| 地图叠加 | MKTileOverlay / MKPolyline / MKPolygon | 全部 MapKit 原生，跟随地图拖拽 |
| 犯罪热力图 | `CrimeTileOverlay: MKTileOverlay` | 后台线程 CGContext 渲染 64×64 tile |
| 路网数据 | OpenStreetMap Overpass API（实时拉取） | 噪音图层，无需 API Key |
| 空气质量 | Open-Meteo API（免费，无 Key） | 返回真实 us_aqi |
| 地震数据 | USGS Earthquake API | M≥2.5，实时 |
| 学校数据 | 硬编码 130+ 所，按县分类 | 含评级、类型 |
| ZIP 边界 | `bayarea_zips.json`（693KB 捆绑资源） | Census TIGER 2023，445 个 Bay Area ZIP |
| 地址搜索 | `MKLocalSearchCompleter` + `MKLocalSearch` | 模糊补全，偏向湾区 |
| 定位 | `CLLocationManager` | 当前位置 → 自动分析 |
| 构建 | Xcode 16，`PBXFileSystemSynchronizedRootGroup` | 新文件自动加入 target |

### 架构关键决定：SwiftUI Map → UIKit MKMapView

**原因：**
- SwiftUI `MapPolyline` 是 O(n) 视图重建，数百条路会冻结 UI
- SwiftUI `overlay()` 是屏幕空间坐标，地图拖拽时叠加层不跟随
- `UIViewRepresentable` 包装 `MKMapView`：所有叠加层都在 MapKit 坐标空间，完美跟随

**关键文件：**
- `HouseFriend/Views/HFMapView.swift` — `UIViewRepresentable` 包装 `MKMapView`
  - `onMapTap` callback（非 Population 层，tap = no-op）
  - `onMapLongPress` callback（长按 → GPS neighborhood 报告）
  - `onZIPTap` callback（Population 层，tap = ZIP info）
  - `onNoiseFetchCancel` callback（平移时取消 Overpass 请求）
  - `highlightedZIPId: String?` → 高亮选中 ZIP 多边形
  - `zipRenderers: [String: MKPolygonRenderer]` → 渲染器缓存
  - `coordinateInsidePolygon()` → ray-casting 点在 ZIP 多边形内检测
- `HouseFriend/Views/CrimeTileOverlay.swift` — `MKTileOverlay`
  - `static crimeValue(lat:lon:) -> Double` 标准方法
  - 后台线程渲染，MapKit 自动缓存 tile

### ZIP 数据架构（重要）

**数据源：** OpenDataDE/State-zip-code-GeoJSON (Census TIGER 2023)
- CA 原始文件 71MB → 过滤 Bay Area → 445 个 ZIP
- 存放：`HouseFriend/bayarea_zips.json`（693KB，PBXFileSystemSynchronizedRootGroup 自动包含）
- **绝对不能** 把 445 个 ZIP 嵌入 Swift 字面量 —— SourceKitService 会 OOM 崩溃

**加载：** `ZIPCodeData.swift`（65 行）运行时解析 JSON，RDP 简化（≤80 点/ZIP，ε=0.0006°）

---

## 3. 10 大数据图层

| # | 图层 | 渲染方式 | 数据来源 | 覆盖状态 |
|---|------|---------|---------|---------|
| 1 | 🔴 Crime 犯罪率 | `CrimeTileOverlay`（MKTileOverlay，后台 CGContext 渲染） | Gaussian 模型 | ✅ 全湾区 |
| 2 | 🔊 Noise 噪音 | `MKPolyline`（UIKit，≤200 条路） | OSM Overpass API 实时 | ✅ 实时动态 |
| 3 | 🏫 Schools 学校 | `MKAnnotation` 图钉 | 硬编码 130+ 所 | ✅ 全湾区 9 县 |
| 4 | ☢️ Superfund 超级基金 | `MKAnnotation` 图钉 | 硬编码 62 处 | ✅ 全湾区 |
| 5 | 🌋 Earthquake 地震 | `MKCircle` 按震级缩放 | USGS 实时 API | ✅ 实时 |
| 6 | 🔥 Fire Hazard 火灾 | `MKPolygon` | 硬编码 22 区 CAL FIRE | ✅ 全湾区 |
| 7 | ⚡ Electric Lines 电力线 | `MKPolyline` | 硬编码 PG&E 输电走廊 | ⚠️ 仅主干 |
| 8 | 🏠 Supportive Housing 保障房 | `MKAnnotation` 图钉 | 硬编码 | ⚠️ 覆盖偏少 |
| 9 | 💨 Air Quality/Odor 空气 | `MKPolygon` | Open-Meteo API + 硬编码工业区 | ✅ |
| 10 | 👥 Population 人口 | `MKPolygon` ZIP 多边形 + 人口统计 Sheet | Census TIGER 2023 JSON | ✅ 445 个 ZIP |

---

## 4. 已完成功能

### UI
- [x] 右侧竖向 Sidebar（10 个图层切换按钮，ScrollView 防截断）
- [x] 顶部地址搜索栏（`MKLocalSearchCompleter` 模糊补全）
- [x] 底部 Neighborhood Report 面板（**长按**地址后展开）
- [x] 评分卡片（进度环 + A/B/C/D/F 字母评级）
- [x] 图例（Legend）显示在左下角
- [x] 缩放 +/- 按钮（右下角）
- [x] 当前位置按钮
- [x] 激活图层标签（地图顶部 chip）

### 地图图层
- [x] Crime：MKTileOverlay 像素热力图（平滑渐变，跟随地图拖拽）
- [x] Noise：Overpass API 动态拉取每条路，按道路类型着色；平移时 cancelFetch
- [x] Schools：130+ 所，点击显示详情 Sheet
- [x] Superfund：62 处，点击显示详情
- [x] Earthquake：USGS 实时，圆圈大小 = 震级
- [x] Fire Hazard：22 个 CAL FIRE 区域
- [x] Electric Lines、Supportive Housing、Air Quality
- [x] Population：445 个 Census TIGER ZIP，黄色边框，点击 → 粉红高亮 + demographics sheet

### Population 图层 UX（新）
- [x] 点击 ZIP 区域内**任意位置**打开 ZIP 信息（ray-casting 点在多边形内检测）
- [x] ZIP 信息面板开着时点击其他 ZIP → 无缝切换内容，**不关闭再重开**
- [x] 长按地图任意处 → 打开 GPS 坐标的 Neighborhood Report（任何图层均有效）
- [x] 切换图层时自动关闭 ZIP 面板（0.3s 动画后清空 selectedZIP）
- [x] 切换图层时自动关闭 Neighborhood Report 面板（清空 pinnedLocation + scores）
- [x] ZIP 选中后地图飞行居中在 **sheet 弹出后可见区域的中央**（south offset = latSpan × 0.26）

### 数据
- [x] 湾区全 9 县覆盖（Santa Clara、Alameda、SF、San Mateo、Contra Costa、Marin、Sonoma、Napa、Solano）
- [x] 445 个 Bay Area ZIP 多边形（Census TIGER 2023，RDP 简化后约 80 点/ZIP）
- [x] 默认图层：Population（打开 app 就看到 ZIP 地图）
- [x] 默认视图：center (37.450, -122.050)，span 0.06°（街区级别），GPS 定位后自动飞行

### Bug 修复（本期）
- [x] `Int(Double.infinity)` crash in `computeScores()` electricLines case
- [x] 同一函数其余分支防御性修复（noise zone、fire minDist）

---

## 5. 待完成功能

### 高优先级
- [ ] **Noise 图层 UI**：加载中显示 spinner，Overpass 失败时 fallback 到硬编码数据
- [ ] **Loading 动画**：切换图层时显示 spinner overlay（MASTER_PLAN 9.10 规格已写）
- [ ] **Supportive Housing 扩充**：SF、Oakland、Berkeley、San Mateo 的保障房数据

### 中优先级
- [ ] **Crime Details 真实数据**：接入 SF Open Data、Oakland Crime API 替换 mock 数据
- [ ] **学校评级数据**：接入 GreatSchools API 或 CA School Dashboard 数据
- [ ] **Electric Lines 扩充**：加入 115kV 以下配电线路
- [ ] **Neighborhood Report 优化**：每个图层给出具体文字描述（不只是分数）

### 低优先级
- [ ] 深色模式适配
- [ ] iPad 布局优化
- [ ] 分享功能（截图 + 评分卡生成图片）
- [ ] 收藏地址

---

## 6. 已知问题 & Rules

> 每次修完 Bug，必须在这里记录教训（防止下次重蹈覆辙）

### Rules 速查表

| # | 规则 | 简述 |
|---|------|------|
| R001 | CGImage premultiplied alpha | 用 `CGContext.fill()` 而非手动字节格式 |
| R002 | SwiftUI `.overlay()` 位置 | 放在 ZStack 内部，加 `.allowsHitTesting(false)` |
| R003 | Xcode 16 自动同步 | 新文件放对目录即可，不用改 pbxproj |
| R004 | Shell heredoc `$` 展开 | 含 `$` 的字符串用 Python scp 上传，不用 heredoc |
| R005 | Sidebar 按钮截断 | 必须用 `ScrollView`，`maxHeight 380` |
| R006 | MKLocalSearch 模糊度 | 用 `MKLocalSearchCompleter` 做实时补全 |
| R007 | Gaussian 衰减单位 | 必须用英里：`exp(-distMiles²/radius²)`，半径 2-5mi |
| R008 | Swift 字面量数组 >5K 行 | SourceKitService OOM 崩溃，改用 bundled JSON |
| R009 | PBXFileSystemSynchronized 重复 | 手动加 pbxproj + 自动同步 → "Multiple commands produce" |
| R010 | `Int(Double.infinity)` crash | 在所有 `Int(someDouble)` 前 `guard value.isFinite` |
| R011 | `.sheet(item:)` 无缝切换 | 改用 `.sheet(isPresented:)` + 独立 content state |

### 详细说明

**R008 - Swift 字面量大数组导致 Mac 崩溃**
- 问题：32941 行 `ZIPCodeData.swift`（445 个 ZIP 内嵌 Swift 数组字面量）→ SourceKitService >10GB RAM，Mac 崩溃
- 教训：**永远不要把大数据集嵌入 Swift 字面量**，改用 bundled JSON 在运行时加载
- 解决：`bayarea_zips.json`（693KB）+ `ZIPCodeData.swift`（65 行）运行时解析

**R010 - `Int(Double.infinity)` 是 Swift 未定义行为**
- 问题：`electricService.lines` 为空 → `minLineDistDeg` 保持 `Double.infinity` → `Int(infinity)` → EXC_BAD_INSTRUCTION
- Swift 不做 safe conversion，直接 trap
- 教训：任何 Double→Int 转换前必须 `guard value.isFinite`，或用 `min(cap, Int(value))` 防御
- 涉及文件：`ContentView.swift` `computeScores()` 所有分支

**R011 - `.sheet(item:)` 换 item 时会 dismiss + re-present**
- 问题：用户点击另一个 ZIP 时，`.sheet(item: $selectedZIP)` 先关闭旧 sheet，再打开新 sheet → 动画闪烁
- 解决：`@State var showZIPSheet = false` + `.sheet(isPresented: $showZIPSheet)` + 内容里读 `selectedZIP`
- 关键：`selectedZIP = newRegion` 必须在 `showZIPSheet = true` 之前（同一 run loop batch 批量提交）

### 当前已知限制
- Overpass API 在 Mac 本地测试超时（504），iOS 设备直连正常
- Crime 热力图是 Gaussian 模型估算，非逐街道真实犯罪数据
- 学校评分为静态硬编码，非实时 API
- Supportive Housing 数据在 SF、Oakland、Berkeley 偏少

---

## 7. 数据覆盖范围

### 湾区 9 县覆盖状态

| 县 | 学校 | 犯罪 | 火灾 | ZIP 边界 |
|----|------|------|------|---------|
| Santa Clara | ✅ 36 所 | ✅ | ✅ | ✅ Census TIGER |
| Alameda | ✅ 29 所 | ✅ | ✅ | ✅ Census TIGER |
| San Francisco | ✅ 13 所 | ✅ | ✅ | ✅ Census TIGER |
| San Mateo | ✅ 16 所 | ✅ | ✅ | ✅ Census TIGER |
| Contra Costa | ✅ 17 所 | ✅ | ✅ | ✅ Census TIGER |
| Marin | ✅ 8 所 | ✅ | ✅ | ✅ Census TIGER |
| Sonoma | ✅ 5 所 | ⚠️ 少 | ✅ | ✅ Census TIGER |
| Napa | ⚠️ 少 | ⚠️ 少 | ⚠️ 少 | ✅ Census TIGER |
| Solano | ⚠️ 少 | ✅ Vallejo | ⚠️ 少 | ✅ Census TIGER |

---

## 8. 文件结构

```
HouseFriend/
├── bayarea_zips.json               # 445 Bay Area ZIP 多边形（Census TIGER 2023，693KB）
├── Models/
│   ├── Category.swift              # CategoryType enum, NeighborhoodCategory
│   ├── CrimeMarker.swift           # CrimeMarker, CrimeType
│   ├── MapZone.swift               # MapZone (polygon + value)
│   └── ZIPCodeData.swift           # ZIPCodeRegion, ZIPDemographics，运行时加载 JSON（65行）
├── Services/
│   ├── AirQualityService.swift     # Open-Meteo API
│   ├── CrimeService.swift          # SF Open Data + mock
│   ├── EarthquakeService.swift     # USGS API
│   ├── ElectricLinesService.swift  # 硬编码 PG&E 走廊
│   ├── FireDataService.swift       # 硬编码 CAL FIRE 22 区
│   ├── LocationService.swift       # CLLocationManager
│   ├── NoiseService.swift          # Overpass API，cancelFetch()
│   ├── PopulationService.swift     # 硬编码 65 城市人口密度
│   ├── SchoolService.swift         # 硬编码 130+ 学校
│   ├── SearchCompleterService.swift
│   ├── SuperfundService.swift      # 硬编码 62 处
│   └── SupportiveHousingService.swift
├── Views/
│   ├── ContentView.swift           # 主界面（地图 + 所有图层 + ZIP UX）
│   ├── CategoryCardView.swift      # 底部评分卡片
│   ├── CrimeTileOverlay.swift      # MKTileOverlay，后台 CGContext 渲染
│   ├── CrimeMarkerView.swift       # Details 模式标注
│   ├── DetailSheetView.swift       # School/Superfund/Housing 详情 Sheet
│   ├── HFMapView.swift             # UIViewRepresentable MKMapView（核心）
│   ├── LegendView.swift            # 图例
│   └── ZIPDemographicsSheet.swift  # ZIP 人口统计面板
└── Assets.xcassets/
```

### ContentView 关键 State 变量

```swift
@State var mapRegion: MKCoordinateRegion         // 替代原来的 MapCameraPosition
@State var currentCenter: CLLocationCoordinate2D
@State var currentSpan: MKCoordinateSpan
@State var selectedCategory: CategoryType = .population
@State var highlightedZIPId: String?
@State var selectedZIP: ZIPCodeRegion?
@State var showZIPSheet = false                  // 控制 ZIP sheet；用 isPresented 而非 item
@State var pinnedLocation: CLLocationCoordinate2D?
@State var pinnedAddress = ""
@State var isLoadingScores = false
```

### HFMapView 关键 callbacks（ContentView 负责传入）

```swift
var onZIPTap:          (ZIPCodeRegion) -> Void
var onMapTap:          (CLLocationCoordinate2D) -> Void  // 现在是 no-op
var onMapLongPress:    (CLLocationCoordinate2D) -> Void  // 长按 → GPS neighborhood
var onNoiseFetchCancel: () -> Void
```

---

## 9. 功能效果规格（Feature Spec）

### 9.0 Population 人口图层（核心功能）

**视觉效果**
- 445 个 Census TIGER ZIP 区域，黄金色边框（0.88, 0.72, 0.0），70% 不透明度，线宽 1.5
- 未选中：透明填充，只有边框
- 选中（高亮）：粉色填充（systemPink 28%）+ 粉色边框（85%）

**点击交互**
- **点击 ZIP 区域内任意位置** → ray-casting 检测 → 高亮 + 底部弹出 ZIPDemographicsSheet
- **Sheet 开着时点击另一个 ZIP** → 无缝切换（sheet 内容更新，不关闭）
- **Sheet 开着时切换图层** → sheet 自动关闭（0.3s 动画后清空）
- **长按任意地图位置** → 打开 GPS 坐标 Neighborhood Report（任何图层均有效）

**ZIP 地图居中规则**
```
Sheet 高度 = 52% 屏幕
可见地图高度 = 48%
可见区中心 = 距顶 24%（= 全屏中心 50% - 26%）
→ mapRegion.center.latitude = zip.center.latitude - latSpan * 0.26
```

**ZIPDemographicsSheet 包含：**
1. 人种分布（横向堆叠色条）
2. 家庭收入分布（纵向柱状图）
3. 年龄分布（横向条形图）

数据来源：2020 Census，`ZIPDemographics` 结构体字段（全部 Int）：
`population, medianIncome, white, hispanic, asian, black, other`
`incUnder50, inc50_100, inc100_150, inc150_200, inc200Plus`
`age_under18, age_18_34, age_35_54, age_55_74, age_75Plus`
（`medianAge: Double` 是唯一 Double 字段）

---

### 9.1 地址搜索

- 搜索框输入第 1 个字符即出现补全建议（`MKLocalSearchCompleter`）
- 下拉列表分两层：模糊补全（即时）+ 完整结果（含坐标）
- 点击任一建议 → 地图飞到该地址（span ≈ 0.03°）
- 地图上出现红色 📍 Pin，底部面板展开 Neighborhood Report
- 优先显示湾区内结果

---

### 9.2 Crime 犯罪率图层

**MKTileOverlay 渲染规格**
- 后台线程计算每个 Web Mercator tile（z/x/y）的 64×64 像素热力图
- `CrimeTileOverlay.crimeValue(lat:lon:) -> Double` 是标准 API（ContentView 和 tile 都调用）
- Gaussian 模型：每个热点 `exp(-distMiles² / radius²)`，半径 2-5mi

**颜色规格**
| 值 | 颜色 |
|----|------|
| >0.72 | 深红 (191,13,13) |
| 0.55-0.72 | 橙红 (235,64,20) |
| 0.40-0.55 | 橙色 (250,133,38) |
| 0.28-0.40 | 琥珀 (254,184,89) |
| 0.18-0.28 | 浅琥珀 (255,219,153) |
| <0.18 | 米色 (255,238,200) |

---

### 9.3 Noise 噪音图层

- 每条道路是一条 `MKPolyline`，颜色按类型，上限 200 条
- 高速（motorway）：紫色 5px；住宅街：绿色 2px
- 平移地图时 `cancelFetch()` 取消旧 Overpass 请求

---

### 9.4 Neighborhood Report 底部面板

**触发方式：长按地图**（0.45s）→ Pin 落下 → 底部面板展开

**切换图层时自动关闭**（`onChange(of: selectedCategory)` 清空 `pinnedLocation`）

**评分计算注意事项**
- 所有 `Double → Int` 转换必须先 `guard value.isFinite`（R010）
- `electricLines` 分支：无数据时给 75 分 + "Data loading..."
- `fireHazard` 分支：`minDist` 可能为 infinity，用 `safeMinDist`

---

### 9.5 性能 & 加载策略

**按需加载（Lazy Loading）**
- App 启动时只加载 Population（JSON 解析，约 0.1s）
- 其他图层在切换时触发 `loadLayerIfNeeded()`
- 已加载过的图层有 `isLoaded: Bool` 标志，不重复请求

**各图层加载策略**

| 图层 | 联网 | 缓存策略 |
|------|------|---------|
| Crime | 否（纯计算） | 永久缓存 tile（MapKit 自动） |
| Noise | 是（Overpass） | 视野移动 >50% 时刷新 |
| Schools | 否 | 永久（硬编码） |
| Earthquake | 是（USGS） | 30 分钟 TTL |
| Fire / Electric / Housing | 否 | 永久（硬编码） |
| Air Quality | 是（Open-Meteo） | 1 小时 TTL |
| Population | 否（JSON bundle） | 永久 |

---

### 9.6 完整用户旅程

```
打开 app
  ↓
看到湾区 ZIP 地图（Population 层默认，445 个 ZIP 黄边框）
GPS 定位后地图自动飞到当前位置
  ↓
点击一个 ZIP 区域（任意位置）
  ↓
地图居中到该 ZIP（可见区域中央），底部弹出人口统计面板
点击另一个 ZIP → 面板无缝切换（不关闭）
  ↓
切换到 Crime 图层
  ↓
ZIP 面板自动关闭；地图显示犯罪热力图
  ↓
在地图上长按一个 GPS 点（0.45s）
  ↓
Pin 落下，底部展开 Neighborhood Report（各图层评分）
  ↓
切换到 Schools 图层
  ↓
Neighborhood Report 自动关闭；地图显示学校图钉
点击学校图钉 → 详情 Sheet 弹出
  ↓
搜索「1234 Main St, Sunnyvale」
  ↓
地图飞到 Sunnyvale，Pin 落下，底部展开 Neighborhood Report
查看综合评分，横划各图层评分卡
```
