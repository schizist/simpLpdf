import SwiftUI
import PDFKit

struct SelectedOrderView: View {
    let document: PDFDocument
    @Binding var orderedSelectedPages: [Int]

    private let thumbSize = CGSize(width: 80, height: 110)

    var body: some View {
        VStack(alignment: .leading) {
            Text("Reorder Selected Pages")
                .font(.subheadline)
                .padding(.leading, 8)

            List {
                ForEach(orderedSelectedPages.indices, id: \.self) { i in
                    let pageIndex = orderedSelectedPages[i]
                    HStack(spacing: 12) {
                        if let page = document.page(at: pageIndex) {
                            Image(uiImage: page.thumbnail(of: thumbSize, for: .cropBox))
                                .resizable()
                                .frame(width: 60, height: 80)
                                .cornerRadius(4)
                        }
                        Text("Page \(pageIndex + 1)")
                        Spacer()
                        Text("\(i + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onMove(perform: move)
            }
            .environment(\.editMode, .constant(.active))
            .frame(height: 200)
        }
    }

    private func move(from: IndexSet, to: Int) {
        orderedSelectedPages.move(fromOffsets: from, toOffset: to)
    }
}
