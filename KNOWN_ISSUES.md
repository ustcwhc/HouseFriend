# Known Issues & Rules

> After every bug fix, the lesson must be recorded here to prevent repeating the same mistakes.

---

## Rules Quick Reference

| # | Rule | Summary |
|---|------|---------|
| R001 | CGImage premultiplied alpha | Use `CGContext.fill()` instead of manual byte format |
| R002 | SwiftUI `.overlay()` placement | Place inside ZStack, add `.allowsHitTesting(false)` |
| R003 | Xcode 16 auto-sync | Just place new files in the correct directory, no need to modify pbxproj |
| R004 | Shell heredoc `$` expansion | Use Python scp for strings containing `$`, avoid heredoc |
| R005 | Sidebar button clipping | Must use `ScrollView`, `maxHeight 380` |
| R006 | MKLocalSearch fuzziness | Use `MKLocalSearchCompleter` for real-time autocomplete |
| R007 | Gaussian decay units | Must use miles: `exp(-distMiles^2/radius^2)`, radius 2-5mi |
| R008 | Swift literal arrays >5K lines | SourceKitService OOM crash, use bundled JSON instead |
| R009 | PBXFileSystemSynchronized duplication | Manual pbxproj entry + auto-sync -> "Multiple commands produce" |
| R010 | `Int(Double.infinity)` crash | `guard value.isFinite` before all `Int(someDouble)` conversions |
| R011 | `.sheet(item:)` seamless switch | Use `.sheet(isPresented:)` + separate content state instead |

---

## Detailed Explanations

### R008 - Large Swift literal arrays crash Mac

- **Problem:** 32941-line `ZIPCodeData.swift` (445 ZIPs embedded as Swift array literals) -> SourceKitService >10GB RAM, Mac crashes
- **Lesson:** Never embed large datasets as Swift literals. Use bundled JSON loaded at runtime.
- **Solution:** `bayarea_zips.json` (693 KB) + `ZIPCodeData.swift` (65 lines) runtime parsing

### R010 - `Int(Double.infinity)` is undefined behavior in Swift

- **Problem:** `electricService.lines` is empty -> `minLineDistDeg` stays `Double.infinity` -> `Int(infinity)` -> EXC_BAD_INSTRUCTION
- **Note:** Swift does not perform safe conversion, it traps directly
- **Lesson:** Always `guard value.isFinite` before any Double->Int conversion, or use `min(cap, Int(value))`
- **Affected file:** `ContentView.swift` `computeScores()` all branches

### R011 - `.sheet(item:)` dismisses and re-presents when item changes

- **Problem:** When user taps another ZIP, `.sheet(item: $selectedZIP)` first dismisses the old sheet, then presents the new one -> animation flicker
- **Solution:** `@State var showZIPSheet = false` + `.sheet(isPresented: $showZIPSheet)` + read `selectedZIP` inside the content
- **Key:** `selectedZIP = newRegion` must come before `showZIPSheet = true` (batched in the same run loop)

---

## Current Known Limitations

- Overpass API times out (504) on Mac local testing; works fine on iOS device direct connection
- Crime heatmap is a Gaussian model estimate, not real per-street crime data
- School ratings are static hardcoded data, not from a real-time API
- Supportive Housing data is sparse in SF, Oakland, Berkeley
