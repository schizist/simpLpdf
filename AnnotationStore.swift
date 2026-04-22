import Foundation
import PencilKit

final class AnnotationStore {
    static let shared = AnnotationStore()
    private var lock = NSLock()
    private var drawings: [Int: PKDrawing] = [:]

    private init() {}

    func set(_ drawing: PKDrawing, for page: Int) {
        lock.lock(); defer { lock.unlock() }
        drawings[page] = drawing
    }

    func drawing(for page: Int) -> PKDrawing? {
        lock.lock(); defer { lock.unlock() }
        return drawings[page]
    }

    func remove(for page: Int) {
        lock.lock(); defer { lock.unlock() }
        drawings[page] = nil
    }
}
