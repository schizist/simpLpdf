import SwiftUI
import PDFKit
import UIKit

struct ThumbnailsView: View {
    let document: PDFDocument
    @Binding var selectedPages: Set<Int>
    // optional ordered selection to show index badges
    var orderedSelectedPages: [Int]? = nil
    var selectionToggled: ((Int) -> Void)? = nil

    private let thumbSize = CGSize(width: 120, height: 160)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 12) {
                ForEach(0..<(document.pageCount), id: \.self) { index in
                    let image = thumbnailImage(for: index)
                    // compute order badge if present
                    let order = orderedSelectedPages?.firstIndex(of: index).map { $0 + 1 }
                    ThumbnailItem(image: image, index: index, isSelected: selectedPages.contains(index), order: order) {
                        if let cb = selectionToggled {
                            cb(index)
                        } else {
                            toggle(index: index)
                        }
                    }
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
