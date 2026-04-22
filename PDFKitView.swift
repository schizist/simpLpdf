import SwiftUI
import PDFKit
import UIKit

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onUndo: onUndo, onRedo: onRedo)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.backgroundColor = .systemBackground
        pdfView.document = document

        // Two-finger tap -> undo
        let twoFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.numberOfTapsRequired = 1
        twoFingerTap.cancelsTouchesInView = false
        twoFingerTap.delegate = context.coordinator
        pdfView.addGestureRecognizer(twoFingerTap)

        // Three-finger tap -> redo
        let threeFingerTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleThreeFingerTap(_:)))
        threeFingerTap.numberOfTouchesRequired = 3
        threeFingerTap.numberOfTapsRequired = 1
        threeFingerTap.cancelsTouchesInView = false
        threeFingerTap.delegate = context.coordinator
        pdfView.addGestureRecognizer(threeFingerTap)

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document != document {
            uiView.document = document
        }
        // update coordinator callbacks in case closures changed
        context.coordinator.onUndo = onUndo
        context.coordinator.onRedo = onRedo
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onUndo: (() -> Void)?
        var onRedo: (() -> Void)?

        init(onUndo: (() -> Void)?, onRedo: (() -> Void)?) {
            self.onUndo = onUndo
            self.onRedo = onRedo
        }

        @objc func handleTwoFingerTap(_ recognizer: UITapGestureRecognizer) {
            onUndo?()
        }

        @objc func handleThreeFingerTap(_ recognizer: UITapGestureRecognizer) {
            onRedo?()
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow the tap gestures to coexist with scrolling/zooming
            return true
        }
    }
}
