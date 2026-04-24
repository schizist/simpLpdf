import SwiftUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct ThumbnailsView: View {
    let document: PDFDocument
    @Binding var selectedPages: Set<Int>
    @Binding var orderedSelectedPages: [Int]
    var selectionToggled: ((Int) -> Void)? = nil

    @State private var draggingPage: Int? = nil
    @State private var thumbFrames: [Int: CGRect] = [:]

    private let thumbSize = CGSize(width: 120, height: 160)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 12) {
                ForEach(0..<document.pageCount, id: \.self) { index in
                    let image = thumbnailImage(for: index)
                    let order = orderedSelectedPages.firstIndex(of: index).map { $0 + 1 }

                    ThumbnailItem(
                        image: image,
                        index: index,
                        isSelected: selectedPages.contains(index),
                        order: order
                    ) {
                        if let cb = selectionToggled {
                            cb(index)
                        } else {
                            toggle(index: index)
                        }
                    }
                    .scaleEffect(draggingPage == index ? 1.05 : 1.0)
                    .opacity((draggingPage != nil && draggingPage != index) ? 0.85 : 1.0)
                    .onDrag {
                        guard selectedPages.contains(index) else {
                            return NSItemProvider()
                        }
                        draggingPage = index
                        return NSItemProvider(object: NSString(string: "\(index)"))
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ThumbFramePreferenceKey.self,
                                value: [index: geo.frame(in: .global)]
                            )
                        }
                    )
                    .onDrop(
                        of: [UTType.plainText],
                        delegate: ThumbnailDropDelegate(
                            targetIndex: index,
                            orderedSelectedPages: $orderedSelectedPages,
                            draggingPage: $draggingPage,
                            frameFor: { thumbFrames[$0] }
                        )
                    )
                }
            }
            .padding(12)
            .onPreferenceChange(ThumbFramePreferenceKey.self) { value in
                thumbFrames = value
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func toggle(index: Int) {
        if selectedPages.contains(index) {
            selectedPages.remove(index)
            orderedSelectedPages.removeAll { $0 == index }
        } else {
            selectedPages.insert(index)
            if !orderedSelectedPages.contains(index) {
                orderedSelectedPages.append(index)
            }
        }
    }

    private func thumbnailImage(for index: Int) -> UIImage {
        guard let page = document.page(at: index) else {
            return UIImage()
        }
        return page.thumbnail(of: thumbSize, for: .cropBox)
    }
}

private struct ThumbFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct ThumbnailDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var orderedSelectedPages: [Int]
    @Binding var draggingPage: Int?
    var frameFor: (Int) -> CGRect?

    func validateDrop(info: DropInfo) -> Bool {
        draggingPage != nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let dragged = draggingPage else { return false }

        DispatchQueue.main.async {
            insertDragged(dragged: dragged, info: info)
            draggingPage = nil
        }

        return true
    }

    func dropExited(info: DropInfo) {
        draggingPage = nil
    }

    private func insertDragged(dragged: Int, info: DropInfo) {
        guard let from = orderedSelectedPages.firstIndex(of: dragged) else { return }

        var arr = orderedSelectedPages
        arr.remove(at: from)

        let targetFrame = frameFor(targetIndex) ?? .zero
        let dropX = info.location.x
        let midX = targetFrame.midX

        let toIdx = arr.firstIndex(of: targetIndex) ?? arr.count
        let destination = dropX < midX ? toIdx : toIdx + 1
        let insertIndex = min(max(0, destination), arr.count)

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
                } else if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                                .font(.system(size: 12, weight: .semibold))
                        )
                        .offset(x: -6, y: 6)
                        .zIndex(1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}