import Carbon.HIToolbox
import XCTest
@testable import F4Core

final class MediaF4KeyTests: XCTestCase {
    func testSpotlightLaunchpadAndDashboardAreTheMediaF4Key() {
        XCTAssertTrue(MediaF4Key.isMediaF4(keyCode: 177))
        XCTAssertTrue(MediaF4Key.isMediaF4(keyCode: 131))
        XCTAssertTrue(MediaF4Key.isMediaF4(keyCode: 130))
    }

    func testOtherKeysAreNot() {
        // The real F4, Mission Control (F3) and Dictation (F5) are left alone.
        for keyCode in [kVK_F4, 160, 176, kVK_ANSI_4, kVK_Space] {
            XCTAssertFalse(MediaF4Key.isMediaF4(keyCode: keyCode), "\(keyCode)")
        }
    }

    func testMediaKeyCodesAreNotFunctionKeys() {
        XCTAssertTrue(MediaF4Key.keyCodes.isDisjoint(with: ShortcutRules.functionKeyCodes))
    }

    func testDecodesALaunchpadPress() {
        let down = MediaF4Key.MediaKeyPress(data1: (13 << 16) | (0xA << 8))
        XCTAssertEqual(down.key, MediaF4Key.launchpadMediaKey)
        XCTAssertTrue(down.isDown)
        XCTAssertFalse(down.isRepeat)

        let up = MediaF4Key.MediaKeyPress(data1: (13 << 16) | (0xB << 8))
        XCTAssertFalse(up.isDown)

        let held = MediaF4Key.MediaKeyPress(data1: (13 << 16) | (0xA << 8) | 1)
        XCTAssertTrue(held.isDown)
        XCTAssertTrue(held.isRepeat)
    }

    func testDecodesAVolumeKeyAsAnotherKey() {
        let volumeUp = MediaF4Key.MediaKeyPress(data1: (0 << 16) | (0xA << 8))
        XCTAssertNotEqual(volumeUp.key, MediaF4Key.launchpadMediaKey)
    }

    func testCatchesOnlyWhenEverythingLinesUp() {
        XCTAssertTrue(MediaF4Key.shouldCatch(settingIsOn: true, shortcutKeyCode: kVK_F4, shortcutModifiers: 0, functionKeysAreStandard: false))
        XCTAssertFalse(MediaF4Key.shouldCatch(settingIsOn: false, shortcutKeyCode: kVK_F4, shortcutModifiers: 0, functionKeysAreStandard: false))
        XCTAssertFalse(MediaF4Key.shouldCatch(settingIsOn: true, shortcutKeyCode: kVK_F5, shortcutModifiers: 0, functionKeysAreStandard: false))
        XCTAssertFalse(MediaF4Key.shouldCatch(settingIsOn: true, shortcutKeyCode: kVK_F4, shortcutModifiers: cmdKey, functionKeysAreStandard: false))
        XCTAssertFalse(MediaF4Key.shouldCatch(settingIsOn: true, shortcutKeyCode: kVK_F4, shortcutModifiers: 0, functionKeysAreStandard: true))
    }
}
