import SwiftData

extension DemoController: CoverControlling {

    func openCover(_ id: String) async {
        guard let cover = CoverEntity.fetch(byId: id, in: context) else { return }
        cover.state = .opening
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        guard let cover = CoverEntity.fetch(byId: id, in: context) else { return }
        cover.state = .open
        cover.currentPosition = 100
    }

    func closeCover(_ id: String) async {
        guard let cover = CoverEntity.fetch(byId: id, in: context) else { return }
        cover.state = .closing
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        guard let cover = CoverEntity.fetch(byId: id, in: context) else { return }
        cover.state = .closed
        cover.currentPosition = 0
    }

    func setPosition(of id: String, to position: Int) async {
        guard let cover = CoverEntity.fetch(byId: id, in: context) else { return }
        cover.state = position > (cover.currentPosition ?? 0) ? .opening : .closing
        try? await Task.sleep(for: .milliseconds(1500))
        guard !Task.isCancelled else { return }
        guard let cover = CoverEntity.fetch(byId: id, in: context) else { return }
        cover.currentPosition = position
        cover.state = position > 0 ? .open : .closed
    }

    func stopCover(_ id: String) async {
        guard let cover = CoverEntity.fetch(byId: id, in: context) else { return }
        if cover.currentPosition == 0 {
            cover.state = .closed
        } else {
            cover.state = .open
        }
    }

    func toggleCover(_ id: String) async {
        guard let cover = CoverEntity.fetch(byId: id, in: context) else { return }
        if cover.state == .closed {
            await openCover(id)
        } else {
            await closeCover(id)
        }
    }
}
