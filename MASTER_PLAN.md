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
| 10 | 👥 Population 人口 | MapAnnotation 文字 | 硬编码 65 城市人口密度 | ✅ |

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

*最后更新：2026-03-08 | GitHub: ustcwhc/HouseFriend*
