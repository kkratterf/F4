import XCTest
@testable import F4Core

final class LibraryFoldersTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/stanis", isDirectory: true)

    func testAppLibraryIsInApplicationSupport() {
        XCTAssertEqual(
            LibraryFolders.appLibrary(home: home).path,
            "/Users/stanis/Library/Application Support/F4/Memes"
        )
        XCTAssertEqual(LibraryFolders.legacyFolder(home: home).path, "/Users/stanis/Pictures/Memes")
    }

    func testInitialFolderKeepsTheUsersChoice() {
        let initial = LibraryFolders.initialFolder(savedPath: "/Volumes/Memes", legacyHasMemes: true, home: home)
        XCTAssertEqual(initial.url.path, "/Volumes/Memes")
        XCTAssertFalse(initial.persist)
    }

    func testInitialFolderKeepsPicturesMemesWhenItHasMemes() {
        let initial = LibraryFolders.initialFolder(savedPath: nil, legacyHasMemes: true, home: home)
        XCTAssertEqual(initial.url.path, "/Users/stanis/Pictures/Memes")
        XCTAssertTrue(initial.persist)
    }

    func testInitialFolderIsTheAppLibraryForANewUser() {
        for saved in [nil, ""] {
            let initial = LibraryFolders.initialFolder(savedPath: saved, legacyHasMemes: false, home: home)
            XCTAssertEqual(initial.url, LibraryFolders.appLibrary(home: home))
            XCTAssertFalse(initial.persist)
        }
    }

    func testFolderNameIsCleaned() {
        XCTAssertEqual(LibraryFolders.folderName("  Reactions  "), "Reactions")
        XCTAssertEqual(LibraryFolders.folderName("cats/dogs"), "cats dogs")
        XCTAssertEqual(LibraryFolders.folderName(".hidden"), "hidden")
        XCTAssertEqual(LibraryFolders.folderName("meme"), "meme")
        XCTAssertNil(LibraryFolders.folderName("   "))
        XCTAssertNil(LibraryFolders.folderName("..."))
    }

    func testUniqueFileNeverOverwrites() {
        let folder = URL(fileURLWithPath: "/tmp/memes", isDirectory: true)
        let taken: Set<String> = ["/tmp/memes/basito.gif", "/tmp/memes/basito 2.gif", "/tmp/memes/GIFs"]
        let exists = { (url: URL) in taken.contains(url.path) }
        XCTAssertEqual(
            LibraryFolders.uniqueFile(base: "basito", pathExtension: "gif", in: folder, exists: exists).lastPathComponent,
            "basito 3.gif"
        )
        XCTAssertEqual(
            LibraryFolders.uniqueFile(base: "dai", pathExtension: "gif", in: folder, exists: exists).lastPathComponent,
            "dai.gif"
        )
        XCTAssertEqual(
            LibraryFolders.uniqueFile(base: "GIFs", pathExtension: "", in: folder, exists: exists).lastPathComponent,
            "GIFs 2"
        )
    }

    func testURLOfACategory() {
        let library = URL(fileURLWithPath: "/tmp/memes", isDirectory: true)
        XCTAssertEqual(LibraryFolders.url(of: nil, in: library), library)
        XCTAssertEqual(LibraryFolders.url(of: "", in: library), library)
        XCTAssertEqual(LibraryFolders.url(of: "reactions/dogs", in: library).path, "/tmp/memes/reactions/dogs")
    }

    func testStarterFilesAreCopiedOnce() {
        let starter = ["GIFs/clown.gif", "GIFs/fire.gif", "Stickers/basito.png"]
        XCTAssertEqual(LibraryFolders.starterFilesToCopy(starter, existing: []), starter)
        XCTAssertEqual(
            LibraryFolders.starterFilesToCopy(starter, existing: ["GIFs/clown.gif"]),
            ["GIFs/fire.gif", "Stickers/basito.png"]
        )
    }

    func testANewStarterFolderIsCopiedToALibraryAlreadySeeded() {
        let starter = ["Emoji/clown.gif", "F4/basito.png", "Maramao/boh.png", "Maramao/bleh.png"]
        XCTAssertEqual(
            LibraryFolders.starterFilesToCopy(starter, existing: [], seeded: LibraryFolders.firstStarterFolders),
            ["Maramao/boh.png", "Maramao/bleh.png"]
        )
        XCTAssertEqual(
            LibraryFolders.starterFilesToCopy(starter, existing: [], seeded: ["Emoji", "F4", "Maramao"]),
            []
        )
        XCTAssertEqual(LibraryFolders.topFolder(of: "Maramao/boh.png"), "Maramao")
        XCTAssertEqual(LibraryFolders.topFolder(of: "a/b/c.png"), "a")
        XCTAssertEqual(LibraryFolders.topFolder(of: "top.png"), "top.png")
    }

    func testTheRetiredStarterFilesAreOnlyEmojiAndF4() {
        let files = LibraryFolders.retiredStarterFiles
        XCTAssertEqual(files.count, 39)
        XCTAssertEqual(Set(files).count, files.count)
        XCTAssertEqual(Set(files.map(LibraryFolders.topFolder(of:))), LibraryFolders.retiredStarterFolders)
        XCTAssertTrue(files.contains("Emoji/clown.gif"))
        XCTAssertTrue(files.contains("F4/basito.png"))
        XCTAssertFalse(LibraryFolders.retiredStarterFolders.contains("Maramao"))
    }

    func testTheCatsFolderCopiedAsMaramaoIsNotCopiedAgain() {
        let seeded = LibraryFolders.currentStarterFolders(["Emoji", "F4", "maramao"])
        XCTAssertEqual(seeded, ["Emoji", "F4", "Maramao"])
        XCTAssertEqual(
            LibraryFolders.starterFilesToCopy(["Maramao/boh.png"], existing: [], seeded: seeded),
            []
        )
        XCTAssertEqual(LibraryFolders.currentStarterFolders(["Reazioni"]), ["Reazioni"])
    }

    func testTheCatsFolderIsRenamedOnlyWhenTheNewNameIsFree() {
        let renames = LibraryFolders.starterFolderRenames(existing: ["maramao", "Reazioni", "a.png"])
        XCTAssertEqual(renames.map(\.from), ["maramao"])
        XCTAssertEqual(renames.map(\.to), ["Maramao"])
        XCTAssertTrue(LibraryFolders.starterFolderRenames(existing: ["Maramao"]).isEmpty)
        XCTAssertTrue(LibraryFolders.starterFolderRenames(existing: ["maramao", "Maramao"]).isEmpty)
        XCTAssertTrue(LibraryFolders.starterFolderRenames(existing: []).isEmpty)
    }

    func testRelocatedPathFollowsMovesAndRenames() {
        XCTAssertEqual(LibraryFolders.relocatedPath("/m/a.gif", from: "/m/a.gif", to: "/m/b.gif"), "/m/b.gif")
        XCTAssertEqual(LibraryFolders.relocatedPath("/m/cats/a.gif", from: "/m/cats", to: "/m/dogs"), "/m/dogs/a.gif")
        XCTAssertNil(LibraryFolders.relocatedPath("/m/catsup/a.gif", from: "/m/cats", to: "/m/dogs"))
        XCTAssertNil(LibraryFolders.relocatedPath("/m/x.gif", from: "/m/a.gif", to: "/m/b.gif"))
    }
}
