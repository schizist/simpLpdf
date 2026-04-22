import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct ThumbnailsView: View {
    let document: PDFDocument
    @Binding var selectedPages: Set<Int>
    // ordered selection used for badges and reordering
    @Binding var orderedSelectedPages: [Int]
    var selectionToggled: ((Int) -> Void)? = nil

    @State private var draggingPage: Int? = nil
    @State private var targetIndex: Int? = nil

    private let thumbSize = CGSize(width: 120, height: 160)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 12) {
                ForEach(0..<(document.pageCount), id: \.self) { index in
                    let image = thumbnailImage(for: index)
                    // compute order badge if present
                    let order = orderedSelectedPages.firstIndex(of: index).map { $0 + 1 }
                    ThumbnailItem(image: image, index: index, isSelected: selectedPages.contains(index), order: order) {
                        if let cb = selectionToggled {
                            cb(index)
                        } else {
                            toggle(index: index)
                        }
                    }
                    .scaleEffect(draggingPage == index ? 1.05 : 1.0)
                    .opacity((draggingPage != nil && draggingPage != index) ? 0.85 : 1.0)
                    // Drag only enabled for selected pages
                    .onDrag {
                        if selectedPages.contains(index) {
                            draggingPage = index
                            return NSItemProvider(object: NSString(string: "\(index)"))
                        }
                        return NSItemProvider()
                    }
                    // Accept drops only on selected pages to reorder
                    .onDrop(of: [UTType.plainText], isTargeted: Binding(get: { targetIndex == index }, set: { isTargeted in
                        if isTargeted {
                            targetIndex = index
                        } else if targetIndex == index {
                            targetIndex = nil
                        }
                    })) { providers in
                        guard selectedPages.contains(index) else { return false }
                        if let provider = providers.first {
                            _ = provider.loadObject(ofClass: NSString.self) { (ns, err) in
                                guard let s = ns as String?, let dragged = Int(s) else { return }
                                DispatchQueue.main.async {
                                    // move dragged in orderedSelectedPages to position of `index`
                                    if let from = orderedSelectedPages.firstIndex(of: dragged) {
                                        if let to = orderedSelectedPages.firstIndex(of: index) {
                                            var arr = orderedSelectedPages
                                            let item = arr.remove(at: from)
                                            // compute adjusted destination after removal
                                            let dest = from < to ? to : to
                                            arr.insert(item, at: dest)
                                            orderedSelectedPages = arr
                                        }
                                    }
                                    draggingPage = nil
                                    targetIndex = nil
                                }
                            }
                            return true
                        }
                        return false
                    }
            }
            .padding(12)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func toggle(index: Int) {
        if selectedPages.contains(index) {
            selectedPages.remove(index)
        } else {
            selectedPages.insert(index)
        }
    }

    private func thumbnailImage(for index: Int) -> UIImage {
        guard let page = document.page(at: index) else {
            return UIImage()
        }
        let thumb = page.thumbnail(of: thumbSize, for: .cropBox)
        return thumb
    }
}

private struct ThumbnailItem: View {
    let image: UIImage
    let index: Int
    let isSelected: Bool
    let order: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 160)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 4)
                    )

                if let n = order, isSelected {
                    Text("\(n)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.accentColor))
                        .offset(x: -6, y: 6)
                } else if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: "checkmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .bold)))
                        .offset(x: -6, y: 6)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
