import XCTest
import CoreGraphics
import CoreText
import ImageIO
@testable import F4Core

final class StickerNamingTests: XCTestCase {
    func testTheCaptionNamesTheSticker() {
        XCTAssertEqual(StickerNaming.caption(["MA CHE", "CAZZO DICI?!"]), "ma che cazzo dici")
        XCTAssertEqual(StickerNaming.caption(["Quando il PM dice", "\"solo una modifica\""]), "quando il pm dice solo una modifica")
        XCTAssertEqual(StickerNaming.caption(["L'ho fatto io"]), "l'ho fatto io")
    }

    func testWatermarksAndNoiseAreNotACaption() {
        XCTAssertNil(StickerNaming.caption(["iZaping.com"]))
        XCTAssertNil(StickerNaming.caption(["HaHaStop.com", "!!"]))
        XCTAssertNil(StickerNaming.caption(["a", "1"]))
        XCTAssertNil(StickerNaming.caption([]))
        XCTAssertEqual(StickerNaming.caption(["boh", "www.memes.it"]), "boh")
    }

    func testALongCaptionIsCutAtAWord() {
        let caption = StickerNaming.caption(["uno due tre quattro cinque sei sette otto nove dieci undici dodici"], maxLength: 20)
        XCTAssertEqual(caption, "uno due tre quattro")
    }

    func testWithoutACaptionTheClearestLabelNamesIt() {
        let labels = [
            StickerNaming.Label(identifier: "animal", confidence: 0.95),
            StickerNaming.Label(identifier: "cat", confidence: 0.9),
            StickerNaming.Label(identifier: "golden_retriever", confidence: 0.2),
        ]
        XCTAssertEqual(StickerNaming.name(text: [], labels: labels), "cat")
        XCTAssertEqual(StickerNaming.label([.init(identifier: "golden_retriever", confidence: 0.6)]), "golden retriever")
        XCTAssertNil(StickerNaming.label([.init(identifier: "cat", confidence: 0.1)]))
        XCTAssertNil(StickerNaming.name(text: ["?"], labels: []))
    }

    func testTheCaptionWinsOverALabel() {
        let labels = [StickerNaming.Label(identifier: "cat", confidence: 0.9)]
        XCTAssertEqual(StickerNaming.name(text: ["Ti prego"], labels: labels), "ti prego")
    }
}

final class StickerNamerTests: XCTestCase {
    /// A white picture with `caption` in big black letters, as PNG.
    private func meme(_ caption: String) throws -> Data {
        let width = 900, height = 400
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 110, nil)
        let text = NSAttributedString(string: caption, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1),
        ])
        let line = CTLineCreateWithAttributedString(text)
        context.textPosition = CGPoint(x: 40, y: 150)
        CTLineDraw(line, context)
        let image = try XCTUnwrap(context.makeImage())
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    func testAMemeIsNamedAfterItsCaption() throws {
        XCTAssertEqual(StickerNamer.name(for: try meme("TI PREGO")), "ti prego")
    }

    func testJunkHasNoName() {
        XCTAssertNil(StickerNamer.name(for: Data("not an image".utf8)))
    }

    func testGenericFileNamesAreRenamed() {
        for name in [
            "WhatsApp Image 2026-11-14 at 20.12.03", "WhatsApp Sticker", "STK-20231105-WA0003",
            "IMG-20231105-WA0001", "IMG_1234", "Screenshot 2026-11-14 at 21.03.11",
            "Schermata 2026-11-14 alle 21.03.11", "image (2)", "sticker_7", "sticker", "1",
            "6F9619FF-8B86-D011-B42D-00C04FC964FF", "a3f9c1e0b2", "Pasted Graphic 3", "unnamed",
            "Senza titolo", "giphy", "PXL_20231105_101010", "",
        ] {
            XCTAssertTrue(StickerNaming.isGenericFileName(name), name)
        }
    }

    func testRealNamesAreKept() {
        for name in ["boh", "cat 2", "ma che dici", "Maramao bleh", "this is fine", "basito_face"] {
            XCTAssertFalse(StickerNaming.isGenericFileName(name), name)
        }
    }
}
