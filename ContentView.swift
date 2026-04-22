import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var pdfDocument: PDFDocument?
    @State private var selectedPages: Set<Int> = []
    @State private var showingImporter = false
    @State private var importErrorMessage: String?
    @State private var showingErrorAlert = false

    var body: some View {
        NavigationView {
            Group {
                if let doc = pdfDocument {
                    VStack(spacing: 0) {
                        PDFKitView(document: doc)
                            .edgesIgnoringSafeArea(.all)
                        ThumbnailsView(document: doc, selectedPages: $selectedPages)
                            .frame(height: 200)
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
    }

    private func loadPDF(from url: URL) {
        if let doc = PDFDocument(url: url) {
            DispatchQueue.main.async {
                self.pdfDocument = doc
                self.selectedPages = []
            }
        } else {
            importErrorMessage = "Failed to open PDF."
            showingErrorAlert = true
        }
    }
}
