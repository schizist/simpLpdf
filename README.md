## simpLpdf

Minimal iPad PDF utility for quick page selection and export.

Implemented features (Milestones 1-3 and 4):

- PDF import via Files picker
- PDF display using PDFKit
- Thumbnail strip with multi-select (tap to select/deselect)
- Export selected pages as one combined PDF
- Export selected pages as separate one-page PDFs (single share sheet)
- Two-finger tap = undo (selection state)
- Three-finger tap = redo (selection state)

Tech:

- Swift, SwiftUI
- PDFKit

Current limitations:

- No annotation editing or PencilKit integration yet
- Undo/redo currently applies to thumbnail selection state only
- iPad/macOS build verification not performed here — open in Xcode to set target and test
- Export filenames and polish are basic (page_001.pdf, combined.pdf)

Next planned milestones:

1. Add thumbnail selection UX polish and multi-select visual improvements
2. Implement annotations and PencilKit overlay with undo/redo for edits
3. Export naming options and bundle exports (ZIP) or cloud saving
4. Automated tests and build verification for iPadOS

Status: functional prototype. Open the Xcode project or create an app target to run on iPad simulator/device.
