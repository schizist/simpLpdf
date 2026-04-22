## simpLpdf

Minimal iPad PDF utility for quick page selection and export.

Implemented features (Milestones 1-4):

- PDF import via Files picker
- PDF display using PDFKit
- Thumbnail strip with multi-select (tap to select/deselect)
- Drag-to-reorder selected thumbnails (controls export order)
- Export selected pages as one combined PDF (preserves ordered selection)
- Export selected pages as separate one-page PDFs (single share sheet)
- PencilKit drawing overlay per page (draw mode toggle)
- Clear drawing on current page
- Export includes drawings burned into exported pages (rasterized)
- Two-finger tap = undo (selection + order snapshot)
- Three-finger tap = redo (selection + order snapshot)

Tech:

- Swift, SwiftUI
- PDFKit, PencilKit

Current limitations:

- Annotations are in-memory PKDrawing objects only (no persistence yet)
- Exported annotations are rasterized images over pages (not native PDF annotation objects)
- Undo/redo currently applies to selection + order snapshots only (not annotation edits)
- iPad/macOS build verification not performed here — open in Xcode to set target and test
- Export filenames and polish are basic (page_001.pdf, combined.pdf)

Known Risks / Needs Real Device Testing:

- PencilKit overlay alignment and sizing during zoom/scroll may differ on device; verify canvas tracks page bounds correctly.
- Gesture conflicts between drawing and PDF navigation (pencil vs. touch vs. multi-finger gestures) should be tested on real iPad.
- Export rendering quality / page scale: rasterization scale may need tuning for high-resolution prints.
- Drag-and-drop reorder behavior and drop-position accuracy should be validated on actual iPad hardware.
- General build verification in Xcode on macOS/iPadOS (signing, entitlements, runtime behavior).

Next planned milestones:

1. Polish annotation UI (tool selection, color, thickness, eraser)
2. Add persistence or embedding of annotations into PDF as vector annotations
3. Improve export naming/metadata and bundle options (ZIP/cloud)
4. Add automated tests and device build verification

Status: functional prototype with drawing and export features; open in Xcode to run on simulator/device.
