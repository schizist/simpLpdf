import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @State private var pdfDocument: PDFDocument?
    @State private var selectedPages: Set<Int> = []
    // Undo / Redo stacks for selection state and order snapshots
    @State private var undoStack: [(Set<Int>, [Int])] = []
    @State private var redoStack: [(Set<Int>, [Int])] = []
    // Ordered list for exports (only pages that are selected)
    @State private var orderedSelectedPages: [Int] = []
    @State private var showingImporter = false
    @State private var importErrorMessage: String?
    @State private var showingErrorAlert = false
    // Export state
    @State private var exportData: Data? = nil
    @State private var exportFileName: String = "export.pdf"
    @State private var showingExporter: Bool = false
    @State private var separateExports: [(Data, String)] = []
    @State private var currentSeparateIndex: Int = 0
    // Activity (share) URLs for single share sheet
    @State private var activityURLs: [URL]? = nil

    var body: some View {
        NavigationView {
            Group {
                if let doc = pdfDocument {
                    VStack(spacing: 0) {
                        PDFKitView(document: doc, onUndo: { undo() }, onRedo: { redo() })
                            .edgesIgnoringSafeArea(.all)
                        ThumbnailsView(document: doc, selectedPages: $selectedPages, orderedSelectedPages: $orderedSelectedPages, selectionToggled: { idx in
                            // record current state then toggle (snapshot selection + order)
                            undoStack.append((selectedPages, orderedSelectedPages))
                            redoStack.removeAll()
                            if selectedPages.contains(idx) {
                                selectedPages.remove(idx)
                                // remove from ordered list if present
                                orderedSelectedPages.removeAll { $0 == idx }
                            } else {
                                selectedPages.insert(idx)
                                // append to ordered list
                                orderedSelectedPages.append(idx)
                            }
                        })
                            .frame(height: 120)

                        // show reordering UI only when there are selected pages
                        if !orderedSelectedPages.isEmpty {
                            SelectedOrderView(document: doc, orderedSelectedPages: $orderedSelectedPages)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)
                        Text("No PDF loaded")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("simpLpdf")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button("Export Combined") {
                            exportCombined()
                        }
                        Button("Export Separate") {
                            exportSeparate()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingImporter = true }) {
                        Image(systemName: "folder")
                    }
                    .accessibilityLabel("Import PDF")
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [UTType.pdf]) { result in
            switch result {
            case .success(let url):
                loadPDF(from: url)
            case .failure(let error):
                importErrorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
        .alert("Import Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "Unknown error")
        }
        // File exporter for combined or separate exports. Uses ExportPDFFile.
        .fileExporter(isPresented: Binding(get: { exportData != nil && showingExporter }, set: { _ in }))
        {
            ExportPDFFile(data: exportData ?? Data())
        } contentType: .pdf { result in
            switch result {
            case .success:
                // combined export finished (or single file export)
                showingExporter = false
                exportData = nil
            case .failure(let error):
                importErrorMessage = "Export failed: \(error.localizedDescription)"
                showingErrorAlert = true
                showingExporter = false
                exportData = nil
            }
        }

        // Present share sheet when activityURLs is set
        .sheet(isPresented: Binding(get: { activityURLs != nil }, set: { if !$0 { activityURLs = nil } })) {
            if let urls = activityURLs {
                ActivityView(urls: urls) {
                    // cleanup temp files after sharing
                    for url in urls {
                        try? FileManager.default.removeItem(at: url)
                    }
                    activityURLs = nil
                }
            } else {
                EmptyView()
            }
        }
    }

    private func loadPDF(from url: URL) {
        if let doc = PDFDocument(url: url) {
            DispatchQueue.main.async {
                self.pdfDocument = doc
                self.selectedPages = []
                self.orderedSelectedPages = []
                self.undoStack.removeAll()
                self.redoStack.removeAll()
            }
        } else {
            importErrorMessage = "Failed to open PDF."
            showingErrorAlert = true
        }
    }

    // MARK: - Undo / Redo

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        // push current state to redo (snapshot both)
        redoStack.append((selectedPages, orderedSelectedPages))
        selectedPages = previous.0
        orderedSelectedPages = previous.1
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        // push current state to undo (snapshot both)
        undoStack.append((selectedPages, orderedSelectedPages))
        selectedPages = next.0
        orderedSelectedPages = next.1
    }

    // MARK: - Export

    private func exportCombined() {
        guard let doc = pdfDocument else { return }
        // use explicit ordered list if available, otherwise default to sorted set
        let indexes = orderedSelectedPages.isEmpty ? selectedPages.sorted() : orderedSelectedPages
        guard !indexes.isEmpty else {
            importErrorMessage = "No pages selected to export."
            showingErrorAlert = true
            return
        }

        let outDoc = PDFDocument()
        for idx in indexes {
            // render page with annotations if present
            if let rendered = renderPageWithAnnotations(doc: doc, index: idx) {
                outDoc.insert(rendered, at: outDoc.pageCount)
            } else if let page = doc.page(at: idx), let copy = page.copy() as? PDFPage {
                outDoc.insert(copy, at: outDoc.pageCount)
            }
        }

        if let data = outDoc.dataRepresentation() {
            exportData = data
            exportFileName = "combined.pdf"
            showingExporter = true
        } else {
            importErrorMessage = "Failed to create combined PDF."
            showingErrorAlert = true
        }
    }

    private func exportSeparate() {
        guard let doc = pdfDocument else { return }
        let indexes = orderedSelectedPages.isEmpty ? selectedPages.sorted() : orderedSelectedPages
        guard !indexes.isEmpty else {
            importErrorMessage = "No pages selected to export."
            showingErrorAlert = true
            return
        }

        // Build PDF data per page and write to temp directory
        var urls: [URL] = []
        let fm = FileManager.default
        let tempBase = fm.temporaryDirectory.appendingPathComponent("simpLpdf_exports_\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: tempBase, withIntermediateDirectories: true, attributes: nil)
            for idx in indexes {
                // render annotated page if necessary
                if let rendered = renderPageWithAnnotations(doc: doc, index: idx) {
                    let single = PDFDocument()
                    single.insert(rendered, at: 0)
                    if let data = single.dataRepresentation() {
                        let name = String(format: "page_%03d.pdf", idx + 1)
                        let fileURL = tempBase.appendingPathComponent(name)
                        try data.write(to: fileURL, options: .atomic)
                        urls.append(fileURL)
                    }
                } else if let page = doc.page(at: idx) {
                    let single = PDFDocument()
                    if let copy = page.copy() as? PDFPage {
                        single.insert(copy, at: 0)
                    }
                    if let data = single.dataRepresentation() {
                        let name = String(format: "page_%03d.pdf", idx + 1)
                        let fileURL = tempBase.appendingPathComponent(name)
                        try data.write(to: fileURL, options: .atomic)
                        urls.append(fileURL)
                    }
                }
            }
        } catch {
            importErrorMessage = "Failed to write temporary export files: \(error.localizedDescription)"
            showingErrorAlert = true
            return
        }

        guard !urls.isEmpty else {
            importErrorMessage = "Failed to build separate PDFs."
            showingErrorAlert = true
            return
        }

        // Present a single share sheet with all file URLs
        activityURLs = urls
    }

    // Render PDF page combined with PKDrawing (if present) into a new PDFPage
    private func renderPageWithAnnotations(doc: PDFDocument, index: Int) -> PDFPage? {
        guard let page = doc.page(at: index) else { return nil }
        let box = page.bounds(for: .mediaBox)
        let size = box.size
        // renderer using device scale for sharper results
        let scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            // draw PDF page
            page.draw(with: .mediaBox, to: ctx.cgContext)

            // draw annotation if exists
            if let drawing = AnnotationStore.shared.drawing(for: index) {
                let drawImg = drawing.image(from: CGRect(origin: .zero, size: size), scale: scale)
                drawImg.draw(in: CGRect(origin: .zero, size: size))
            }
        }

        if let newPage = PDFPage(image: img) {
            return newPage
        }
        return nil
    }
}

// Simple FileDocument wrapper for exporting PDF data
struct ExportPDFFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        if let fileData = configuration.file.regularFileContents {
            data = fileData
        } else {
            data = Data()
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
 
