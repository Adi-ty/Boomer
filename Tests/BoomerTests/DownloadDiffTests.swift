import Testing
@testable import Boomer

struct DownloadDiffTests {
    @Test func browserRenameCountsAsCompletion() {
        // Chrome: movie.zip.crdownload -> movie.zip surfaces as the final name appearing.
        let done = DownloadDiff.completions(added: ["movie.zip"])
        #expect(done == ["movie.zip"])
    }

    @Test func tempFileAppearingIsNotACompletion() {
        #expect(DownloadDiff.completions(added: ["movie.zip.crdownload"]).isEmpty)
        #expect(DownloadDiff.completions(added: ["page.html.download"]).isEmpty)
        #expect(DownloadDiff.completions(added: ["iso.part"]).isEmpty)
    }

    @Test func hiddenFilesAreIgnored() {
        #expect(DownloadDiff.completions(added: [".DS_Store", ".localized"]).isEmpty)
    }

    @Test func directDropsCount() {
        let done = DownloadDiff.completions(added: ["photo.heic", "notes.pdf"])
        #expect(done == ["photo.heic", "notes.pdf"])
    }

    @Test func tempDetectionIsCaseInsensitive() {
        #expect(DownloadDiff.isTemp("X.ZIP.CRDOWNLOAD"))
        #expect(!DownloadDiff.isTemp("archive.zip"))
    }
}
