import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import UIKit
import PencilKit

struct ContentView: View {
    @State private var pdfDocument: PDFDocument?
    @State private var selectedPages: Set<Int> = []
    @State private var undoStack: [(Set<Int>, [Int])] = []
    @State private var redoStack: [(Set<Int>, [Int])] = []
    @State private var orderedSelectedPages: [Int] = []
    @State private var showingImporter = false
    @State private var isDrawingEnabled = false
    @State private var clearSignal = 0
    @State private var importErrorMessage: String?
    @State private var showingErrorAlert = false
    @State private var exportData: Data?
    @State private var exportFileName = "export.pdf"
    @State private var showingExporter = false
    @State private var activityURLs: [URL]? = nil

    var body: some View {
        NavigationView {
            Group {
                if let doc = pdfDocument {
                    VStack(spacing: 0) {
                        PDFKitView(
                            document: doc,
                            isDrawingEnabled: isDrawingEnabled,
                            clearSignal: clearSignal,
                            onUndo: { undo() },
                            onRedo: { redo() }
                        )
                        .edgesIgnoringSafeArea(.all)

                        ThumbnailsView(
                            document: doc,
                            selectedPages: $selectedPages,
                            orderedSelectedPages: $orderedSelectedPages,
                            selectionToggled: { idx in
                                undoStack.append((selectedPages, orderedSelectedPages))
                                redoStack.removeAll()

                                if selectedPages.contains(idx) {
                                    selectedPages.remove(idx)
                                    orderedSelectedPages.removeAll { $0 == idx }
                                } else {
                                    selectedPages.insert(idx)
                                    if !orderedSelectedPages.contains(idx) {
                                        orderedSelectedPages.append(idx)
                                    }
                                }
                            }
                        )
                        .frame(height: 120)

                        if !orderedSelectedPages.isEmpty {
                            SelectedOrderView(
                                document: doc,
                                orderedSelectedPages: $orderedSelectedPages
                            )
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)

                        Text("No PDF loaded")
                            .foregroundColor(.secondary)

                        Button("Import PDF") {
                            showingImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("simpLpdf")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Export Combined") {
                        exportCombined()
                    }

                    Button("Export Separate") {
                        exportSeparate()
                    }
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { isDrawingEnabled.toggle() }) {
                        Image(systemName: isDrawingEnabled ? "pencil.circle.fill" : "pencil.circle")
                    }
                    .accessibilityLabel("Toggle Draw")

                    Button("Clear") {
                        clearSignal += 1
                    }

                    Menu {
                        Button("Import PDF") {
                            showingImporter = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")

                    Button(action: { showingImporter = true }) {
                        Image(systemName: "folder")
                    }
                    .accessibilityLabel("Import PDF")
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf]) { result in
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
        .fileExporter(
            isPresented: Binding(
                get: { exportData != nil && showingExporter },
                set: { _ in }
            ),
            document: ExportPDFFile(data: exportData ?? Data()),
            contentType: .pdf,
            defaultFilename: exportFileName.replacingOccurrences(of: ".pdf", with: "")
        ) { result in
            switch result {
            case .success:
                showingExporter = false
                exportData = nil

            case .failure(let error):
                importErrorMessage = "Export failed: \(error.localizedDescription)"
                showingErrorAlert = true
                showingExporter = false
                exportData = nil
            }
        }
        .sheet(
            isPresented: Binding(
                get: { activityURLs != nil },
                set: {
                    if !$0 { activityURLs = nil }
                }
            )
        ) {
            if let urls = activityURLs {
                ActivityView(urls: urls) {
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
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)

            guard let doc = PDFDocument(data: data) else {
                importErrorMessage = "Failed to read PDF data. The selected file may be damaged or unsupported."
                showingErrorAlert = true
                return
            }

            pdfDocument = doc
            selectedPages = []
            orderedSelectedPages = []
            undoStack.removeAll()
            redoStack.removeAll()
        } catch {
            importErrorMessage = "Failed to import PDF: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append((selectedPages, orderedSelectedPages))
        selectedPages = previous.0
        orderedSelectedPages = previous.1
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append((selectedPages, orderedSelectedPages))
        selectedPages = next.0
        orderedSelectedPages = next.1
    }

    private func exportCombined() {
        guard let doc = pdfDocument else { return }

        let indexes = orderedSelectedPages.isEmpty ? selectedPages.sorted() : orderedSelectedPages
        guard !indexes.isEmpty else {
            importErrorMessage = "No pages selected to export."
            showingErrorAlert = true
            return
        }

        let outDoc = PDFDocument()

        for idx in indexes {
            if let rendered = renderPageWithAnnotations(doc: doc, index: idx) {
                outDoc.insert(rendered, at: outDoc.pageCount)
            } else if let page = doc.page(at: idx), let copy = page.copy() as? PDFPage {
                outDoc.insert(copy, at: outDoc.pageCount)
            }
        }

        guard let data = outDoc.dataRepresentation() else {
            importErrorMessage = "Failed to create combined PDF."
            showingErrorAlert = true
            return
        }

        exportData = data
        exportFileName = "combined.pdf"
        showingExporter = true
    }

    private func exportSeparate() {
        guard let doc = pdfDocument else { return }

        let indexes = orderedSelectedPages.isEmpty ? selectedPages.sorted() : orderedSelectedPages
        guard !indexes.isEmpty else {
            importErrorMessage = "No pages selected to export."
            showingErrorAlert = true
            return
        }

        var urls: [URL] = []
        let fm = FileManager.default
        let tempBase = fm.temporaryDirectory.appendingPathComponent("simpLpdf_exports_\(UUID().uuidString)")

        do {
            try fm.createDirectory(at: tempBase, withIntermediateDirectories: true)

            for idx in indexes {
                let single = PDFDocument()

                if let rendered = renderPageWithAnnotations(doc: doc, index: idx) {
                    single.insert(rendered, at: 0)
                } else if let page = doc.page(at: idx), let copy = page.copy() as? PDFPage {
                    single.insert(copy, at: 0)
                }

                if let data = single.dataRepresentation() {
                    let name = String(format: "page_%03d.pdf", idx + 1)
                    let fileURL = tempBase.appendingPathComponent(name)
                    try data.write(to: fileURL, options: .atomic)
                    urls.append(fileURL)
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

        activityURLs = urls
    }

    private func renderPageWithAnnotations(doc: PDFDocument, index: Int) -> PDFPage? {
        guard let page = doc.page(at: index) else { return nil }

        let box = page.bounds(for: .mediaBox)
        let size = box.size
        let scale = UIScreen.main.scale

        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            page.draw(with: .mediaBox, to: ctx.cgContext)

            if let drawing = AnnotationStore.shared.drawing(for: index) {
                let drawImg = drawing.image(from: CGRect(origin: .zero, size: size), scale: scale)
                drawImg.draw(in: CGRect(origin: .zero, size: size))
            }
        }

        return PDFPage(image: img)
    }
}

struct ExportPDFFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
