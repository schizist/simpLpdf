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
    @State private var thumbFrames: [Int: CGRect] = [:]

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
                    // Accept drops and compute insertion BEFORE/AFTER based on drop x
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: ThumbFramePreferenceKey.self, value: [index: geo.frame(in: .global)])
                    })
                    .onDrop(of: [UTType.plainText], delegate: ThumbnailDropDelegate(targetIndex: index, orderedSelectedPages: $orderedSelectedPages, draggingPage: $draggingPage, frameFor: { thumbFrames[$0] }))
            }
            .padding(12)
            .onPreferenceChange(ThumbFramePreferenceKey.self) { val in
                thumbFrames = val
            }
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

// PreferenceKey for thumbnail frames
private struct ThumbFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// DropDelegate that inserts dragged item before/after target based on drop x position
private struct ThumbnailDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var orderedSelectedPages: [Int]
    @Binding var draggingPage: Int?
    var frameFor: (Int) -> CGRect?

    func validateDrop(info: DropInfo) -> Bool {
        return draggingPage != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let dragged = draggingPage else { return false }
        DispatchQueue.main.async {
            guard let from = orderedSelectedPages.firstIndex(of: dragged) else {
                insertDragged(dragged: dragged, info: info)
                draggingPage = nil
                return
            }
            insertDragged(dragged: dragged, info: info, fromIndex: from)
            draggingPage = nil
        }
        return true
    }

    private func insertDragged(dragged: Int, info: DropInfo, fromIndex: Int? = nil) {
        var arr = orderedSelectedPages
        if let from = fromIndex {
            arr.remove(at: from)
        }

        // compute destination relative to target frame
        let targetFrame = frameFor(targetIndex) ?? .zero
        let dropX = info.location.x
        let midX = targetFrame.midX

        // find current index of target (after removal)
        let toIdx = arr.firstIndex(of: targetIndex) ?? arr.count
        let dest: Int
        if dropX < midX {
            dest = toIdx
        } else {
            dest = toIdx + 1
        }

        let insertIndex = min(max(0, dest), arr.count)
        arr.insert(dragged, at: insertIndex)
        orderedSelectedPages = arr
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
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.accentColor))
                            .offset(x: -6, y: 6)
                            .zIndex(1)
                            .animation(.default, value: order)
                    } else if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 22, height: 22)
                            .overlay(Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .font(.system(size: 12, weight: .semibold)))
                            .offset(x: -6, y: 6)
                            .zIndex(1)
                            .animation(.default, value: order)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
