# Hand-off Notes

Purpose: quick guide for continuing development on simpLpdf.

1) Project goal
- Minimal iPad PDF tool for fast page selection and simple exports using native frameworks.

2) Implemented MVP features
- PDF import via Files picker
- PDF display using PDFKit
- Thumbnail strip with multi-select (tap to toggle)
- Export selected pages as one combined PDF
- Export selected pages as separate one-page PDFs (single share sheet)
- Two-finger tap = undo (selection state)
- Three-finger tap = redo (selection state)

Implemented drawing & reorder features:
- Drag-to-reorder selected thumbnails (controls export order)
- PencilKit overlay per page (draw mode toggle)
- Clear drawing on current page
- Export burns drawings into exported pages (rasterized)

3) Architecture / important files
- `SimpLpdfApp.swift` — app entry point (SwiftUI `@main`).
- `ContentView.swift` — main UI: loads PDF, holds `@State` selection, export logic, undo/redo stacks, presents thumbnails and activity sheet.
- `PDFKitView.swift` — `UIViewRepresentable` wrapping `PDFView`; attaches two/three-finger tap recognizers and exposes `onUndo`/`onRedo` callbacks.
- `ThumbnailsView.swift` — SwiftUI thumbnail strip; renders page thumbnails and toggles selection via a binding or callback.
- `ActivityView.swift` — `UIViewControllerRepresentable` wrapper for `UIActivityViewController` used to share multiple exported files.
- `README.md` — project summary and limitations (kept up-to-date).
 - `AnnotationStore.swift` — simple thread-safe in-memory storage for per-page `PKDrawing` used by export.
 - `SelectedOrderView.swift` — small reorder list fallback UI for ordering selected pages.
 - `ThumbnailsView.swift` — updated to support drag-to-reorder with mid-point drop insertion logic.

4) Known limitations

4) Known limitations
- Annotations are stored in-memory (`AnnotationStore`) and are not persisted to disk or embedded as native PDF annotations.
- Exported annotations are rasterized (images) over pages; vector embedding into PDF is not implemented.
- Undo/redo applies to selection+order snapshots only; annotation edit undo is not implemented.
- iPad/macOS build and automated tests not included; open in Xcode and verify targets.

5) Next recommended milestones (priority order)
5) Next recommended milestones (priority order)
1. Polish annotation UI (tool selection, color, thickness, eraser) and annotation undo/redo.
2. Persist or embed annotations into PDF pages as native annotations (vector) when exporting/saving.
3. Improve export naming/metadata and add bundling/upload options.
4. Validate drag/drop reordering on physical iPad, adjust drop hit testing and visuals.
5. Add unit/UI tests and device build verification.

6) Rules for future contributors / agents
- Keep scope narrow and changes minimal for each commit.
- Avoid adding heavy architecture or view models unless feature complexity requires it.
- Prefer native Apple frameworks (PDFKit, PencilKit, SwiftUI, UIKit) — no third-party dependencies.
- Do not refactor unrelated code; changes must be localized and justified.

Known Risks / Needs Real Device Testing:
- PencilKit overlay alignment during zoom/scroll may differ on device; verify canvas tracks page bounds correctly.
- Gesture conflicts between drawing and PDF navigation (pencil vs. touch vs. multi-finger gestures) should be tested on real iPad.
- Export rendering quality / page scale: rasterization scale may need tuning for print-quality results.
- Drag-and-drop reorder behavior and drop-position accuracy should be validated on actual iPad hardware.
- General build verification in Xcode on macOS/iPadOS (signing, entitlements, runtime behavior).

Contact: refer to the repo owner for design/behavior decisions.
