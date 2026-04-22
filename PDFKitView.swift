import SwiftUI
import PDFKit
import UIKit
import PencilKit

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

        // minimal PencilKit canvas overlay
        let canvas = PKCanvasView(frame: pdfView.bounds)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.alwaysBounceVertical = false
        canvas.isMultipleTouchEnabled = true
        canvas.isUserInteractionEnabled = true
        if #available(iOS 14.0, *) {
            canvas.drawingPolicy = .anyInput
        }
        canvas.becomeFirstResponder()
        pdfView.addSubview(canvas)
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // wire to coordinator
        context.coordinator.canvas = canvas
        context.coordinator.pdfView = pdfView
        // observe layout changes to reposition canvas per-page
        pdfView.addObserver(context.coordinator, forKeyPath: "bounds", options: .new, context: nil)
        pdfView.addObserver(context.coordinator, forKeyPath: "frame", options: .new, context: nil)

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
        context.coordinator.pdfView = uiView
        // ensure canvas is positioned for current page
        context.coordinator.updateCanvasForCurrentPage()
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate, PKCanvasViewDelegate {
        var onUndo: (() -> Void)?
        var onRedo: (() -> Void)?
        weak var pdfView: PDFView?
        weak var canvas: PKCanvasView?
        var drawings: [Int: PKDrawing] = [:]

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

        // MARK: - PencilKit handling
        func updateCanvasForCurrentPage() {
            guard let pdfView = pdfView, let canvas = canvas else { return }
            guard let page = pdfView.currentPage, let doc = pdfView.document else { return }
            let pageIndex = doc.index(for: page)
            let pageBounds = page.bounds(for: pdfView.displayBox)
            let frame = pdfView.convert(pageBounds, from: page)
            // position canvas over the current page
            DispatchQueue.main.async {
                canvas.frame = frame
                canvas.backgroundColor = .clear
                canvas.isOpaque = false
                canvas.isFingerDrawingEnabled = true
                canvas.delegate = self
                if let drawing = self.drawings[pageIndex] {
                    canvas.drawing = drawing
                } else {
                    canvas.drawing = PKDrawing()
                }
            }
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            // reposition canvas when pdfView layout changes
            updateCanvasForCurrentPage()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // save current drawing into drawings for current page
            guard let pdfView = pdfView, let page = pdfView.currentPage, let doc = pdfView.document else { return }
            let pageIndex = doc.index(for: page)
            drawings[pageIndex] = canvasView.drawing
            // also update shared annotation store for export access
            AnnotationStore.shared.set(canvasView.drawing, for: pageIndex)
        }

        deinit {
            if let pdfView = pdfView {
                pdfView.removeObserver(self, forKeyPath: "bounds")
                pdfView.removeObserver(self, forKeyPath: "frame")
            }
        }
    }
}
