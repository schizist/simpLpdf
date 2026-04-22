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

3) Architecture / important files
- `SimpLpdfApp.swift` — app entry point (SwiftUI `@main`).
- `ContentView.swift` — main UI: loads PDF, holds `@State` selection, export logic, undo/redo stacks, presents thumbnails and activity sheet.
- `PDFKitView.swift` — `UIViewRepresentable` wrapping `PDFView`; attaches two/three-finger tap recognizers and exposes `onUndo`/`onRedo` callbacks.
- `ThumbnailsView.swift` — SwiftUI thumbnail strip; renders page thumbnails and toggles selection via a binding or callback.
- `ActivityView.swift` — `UIViewControllerRepresentable` wrapper for `UIActivityViewController` used to share multiple exported files.
- `README.md` — project summary and limitations (kept up-to-date).

4) Known limitations
- No annotation editing or PencilKit integration yet.
- Undo/redo only covers thumbnail selection state (snapshots), not editor annotations.
- Export filenames and metadata are minimal (page_001.pdf, combined.pdf).
- iPad/macOS build and automated tests not included; open in Xcode and verify targets.

5) Next recommended milestones (priority order)
1. Add annotation/PencilKit support with an annotation undo/redo system.
2. Improve export naming and metadata; optionally bundle exports (ZIP) or support cloud targets.
3. Add thumbnail UX polish and selection accessibility improvements.
4. Add unit/UI tests and verify iPad simulator/device builds.

6) Rules for future contributors / agents
- Keep scope narrow and changes minimal for each commit.
- Avoid adding heavy architecture or view models unless feature complexity requires it.
- Prefer native Apple frameworks (PDFKit, PencilKit, SwiftUI, UIKit) — no third-party dependencies.
- Do not refactor unrelated code; changes must be localized and justified.

Contact: refer to the repo owner for design/behavior decisions.
