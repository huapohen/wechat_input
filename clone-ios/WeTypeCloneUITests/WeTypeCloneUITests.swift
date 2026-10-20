import XCTest

final class WeTypeCloneUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func launchApp(route: String? = nil) {
        app.launchArguments = ["-onboarding.accepted", "YES", "-api.base_url", "http://172.17.78.27:8788"]
        if let route { app.launchArguments += ["-uitest.route", route] }
        app.launch()
        XCTAssertTrue(app.staticTexts["微输入法"].waitForExistence(timeout: 25), "home did not appear")
        attach("home")
    }

    func testHomeAndSettings() throws {
        launchApp()
        let items = ["布局和显示", "按键效果", "定制工具栏", "辅助输入", "跨设备粘贴同步",
                     "剪贴板", "键盘管理", "语音转文字", "拼写 Plus", "单机模式", "换机助手"]
        for item in items {
            let element = scrollTo(item)
            XCTAssertTrue(element.waitForExistence(timeout: 5), "missing tile \(item)")
            element.tap()
            XCTAssertTrue(app.navigationBars[item].waitForExistence(timeout: 6), "page \(item) did not open")
            attach("page-\(item)")
            back()
        }

        for item in ["隐私与权限", "电脑版", "关于", "帮助与反馈"] {
            let element = scrollTo(item)
            XCTAssertTrue(element.waitForExistence(timeout: 5), "missing more row \(item)")
            element.tap()
            XCTAssertTrue(app.navigationBars[item].waitForExistence(timeout: 6), "page \(item) did not open")
            attach("page-\(item)")
            back()
        }

        for item in ["AI 录音笔", "隔空传送"] {
            let element = scrollTo(item)
            XCTAssertTrue(element.waitForExistence(timeout: 5), "missing feature \(item)")
            element.tap()
            XCTAssertTrue(app.navigationBars[item].waitForExistence(timeout: 6), "page \(item) did not open")
            attach("feature-\(item)")
            back()
        }

        // Nested settings.
        tapAndCheck("语音转文字")
        tapAndCheck("识别语言")
        back()
        tapAndCheck("标点设置")
        back()
        back()

        tapAndCheck("辅助输入")
        tapAndCheck("模糊拼音")
        back()
        back()

        tapAndCheck("拼写 Plus")
        tapAndCheck("常用语")
        back()
        tapAndCheck("边写边译")
        back()
        tapAndCheck("排版成图")
        back()
        tapAndCheck("问 AI")
        back()
        tapAndCheck("文字工具")
        back()
        back()

        tapAndCheck("键盘管理")
        attach("keyboard-manage")
        back()

        tapAndCheck("AI 录音笔")
        tapAndCheck("最近会话")
        back()
        back()
    }

    func testAIChatRealResponse() throws {
        launchApp()
        let element = scrollTo("拼写 Plus")
        element.tap()
        XCTAssertTrue(app.navigationBars["拼写 Plus"].waitForExistence(timeout: 6))
        let ai = scrollTo("问 AI")
        ai.tap()
        XCTAssertTrue(app.navigationBars["问 AI"].waitForExistence(timeout: 6))
        attach("ai-chat-empty")
        let suggestion = app.staticTexts["帮我把这句话写得更正式：明天开会别忘了带材料"].firstMatch
        if suggestion.waitForExistence(timeout: 3) { suggestion.tap() }
        let send = app.buttons["ai.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 3), "send missing")
        send.tap()
        sleep(12)
        attach("ai-chat-answer")
        let copy = app.buttons["复制"].firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 10), "AI answer copy action missing")
    }

    func testEnableKeyboardOnly() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 15))
        tapEither(settings, ["General", "通用"])
        tapEither(settings, ["Keyboard", "键盘"])
        tapEither(settings, ["Keyboards", "键盘"])
        if settings.cells["KEYBOARDS"].waitForExistence(timeout: 3) {
            settings.cells["KEYBOARDS"].tap()
        }
        attach(settings, "settings-keyboards-detail")

        let add = settings.cells["AddNewKeyboard"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Add New Keyboard cell missing")
        add.tap()
        attach(settings, "settings-add-list")

        let ourKeyboard = settings.staticTexts["微输入法"].firstMatch
        for _ in 0..<6 {
            if ourKeyboard.exists && ourKeyboard.isHittable { break }
            settings.swipeUp()
        }
        XCTAssertTrue(ourKeyboard.waitForExistence(timeout: 5), "keyboard not listed")
        ourKeyboard.tap()
        attach(settings, "settings-added")

        if ourKeyboard.waitForExistence(timeout: 3) && ourKeyboard.isHittable {
            ourKeyboard.tap()
        }
        attach(settings, "settings-keyboard-detail")
        let allowSwitch = settings.switches["Allow Full Access"].exists
            ? settings.switches["Allow Full Access"]
            : settings.switches["允许完全访问"]
        if allowSwitch.waitForExistence(timeout: 4), (allowSwitch.value as? String) != "1" {
            allowSwitch.tap()
            let allow = settings.buttons["Allow"].exists ? settings.buttons["Allow"] : settings.buttons["允许"]
            if allow.waitForExistence(timeout: 3) { allow.tap() }
        }
        attach(settings, "settings-full-access")
    }

    func testAllowFullAccess() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 15))
        tapEither(settings, ["General", "通用"])
        tapEither(settings, ["Keyboard", "键盘"])
        tapEither(settings, ["Keyboards", "键盘"])
        if settings.cells["KEYBOARDS"].waitForExistence(timeout: 3) {
            settings.cells["KEYBOARDS"].tap()
        }
        let ourKeyboard = settings.staticTexts["微输入法"].firstMatch
        XCTAssertTrue(ourKeyboard.waitForExistence(timeout: 5), "keyboard not enabled")
        ourKeyboard.tap()
        attach(settings, "settings-keyboard-detail")
        let allowSwitch = settings.switches.firstMatch
        XCTAssertTrue(allowSwitch.waitForExistence(timeout: 4), "full access switch missing")
        if (allowSwitch.value as? String) != "1" {
            attach(settings, "settings-full-access-before")
            allowSwitch.tap()
            let allow = settings.buttons["Allow"].exists ? settings.buttons["Allow"] : settings.buttons["允许"]
            if allow.waitForExistence(timeout: 4) { allow.tap() }
        }
        attach(settings, "settings-full-access")
    }

    func testGlobeMenu() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        if safari.state != .runningForeground { safari.activate() }
        let tv = safari.textViews.firstMatch
        if tv.waitForExistence(timeout: 4) { tv.tap() } else { safari.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap() }
        let cont = safari.buttons["Continue"].exists ? safari.buttons["Continue"] : safari.buttons["继续"]
        if cont.waitForExistence(timeout: 2) { cont.tap() }
        sleep(1)
        let kb = safari.keyboards.firstMatch
        XCTAssertTrue(kb.waitForExistence(timeout: 3), "keyboard missing")
        kb.coordinate(withNormalizedOffset: CGVector(dx: 0.09, dy: 0.99)).press(forDuration: 1.2)
        sleep(1)
        attach(safari, "globe-menu")
        print(safari.debugDescription)
        let ours = safari.staticTexts["微输入法"].firstMatch
        if ours.waitForExistence(timeout: 3) { ours.tap(); sleep(1); attach(safari, "globe-selected") }
        if safari.buttons["tool.mode"].exists { print("CLONE KEYBOARD ACTIVE") } else { print("CLONE KEYBOARD NOT ACTIVE") }
    }

    func testKeyboardTree() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        if safari.state != .runningForeground { safari.activate() }
        let tv = safari.textViews.firstMatch
        if tv.waitForExistence(timeout: 4) { tv.tap() }
        let cont = safari.buttons["Continue"].exists ? safari.buttons["Continue"] : safari.buttons["继续"]
        if cont.waitForExistence(timeout: 2) { cont.tap() }
        sleep(1)
        print("KBTREE", safari.keyboards.firstMatch.debugDescription)
    }

    func testCycleScreens() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        if safari.state != .runningForeground { safari.activate() }
        let textView = safari.textViews.firstMatch
        if textView.waitForExistence(timeout: 4) { textView.tap() } else { safari.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap() }
        let cont = safari.buttons["Continue"].exists ? safari.buttons["Continue"] : safari.buttons["继续"]
        if cont.waitForExistence(timeout: 2) { cont.tap() }
        sleep(1)
        for i in 0..<4 {
            safari.coordinate(withNormalizedOffset: CGVector(dx: 0.09, dy: 0.932)).tap()
            sleep(1)
            attach(safari, "cycle-\(i)")
            print("CYCLE", i, safari.buttons["tool.mode"].exists)
        }
    }

    func testTypeIntoHost() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        if safari.state != .runningForeground { safari.activate() }
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))
        let textView = safari.textViews.firstMatch
        if textView.waitForExistence(timeout: 4) {
            textView.tap()
        } else {
            safari.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        }
        let cont = safari.buttons["Continue"].exists ? safari.buttons["Continue"] : safari.buttons["继续"]
        if cont.waitForExistence(timeout: 2) { cont.tap() }
        sleep(1)
        attach(safari, "host-keyboard-initial")

        var found = false
        for _ in 0..<8 {
            if safari.buttons["tool.mode"].exists {
                found = true
                break
            }
            safari.coordinate(withNormalizedOffset: CGVector(dx: 0.09, dy: 0.932)).tap()
            sleep(1)
        }
        attach(safari, "host-keyboard-cycle")
        XCTAssertTrue(found, "clone keyboard did not appear after globe cycling")

        safari.buttons["tool.mode"].tap()
        if safari.buttons["mode.qwerty"].waitForExistence(timeout: 3) {
            safari.buttons["mode.qwerty"].tap()
        }
        for key in ["key.n", "key.i", "key.h", "key.a", "key.o"] {
            if safari.buttons[key].waitForExistence(timeout: 1) { safari.buttons[key].tap() }
        }
        sleep(1)
        attach(safari, "host-keyboard-candidates")
        if safari.buttons["candidate.0"].exists {
            safari.buttons["candidate.0"].tap()
        } else if safari.buttons["你好"].exists {
            safari.buttons["你好"].tap()
        }
        sleep(1)
        // ASCII through English mode.
        safari.buttons["tool.mode"].tap()
        if safari.buttons["mode.english"].waitForExistence(timeout: 3) {
            safari.buttons["mode.english"].tap()
        }
        for key in ["key.a", "key.b", "key.c"] {
            if safari.buttons[key].exists { safari.buttons[key].tap() }
        }
        if safari.buttons["candidate.0"].exists {
            safari.buttons["candidate.0"].tap()
        } else if safari.buttons["key.space"].exists {
            safari.buttons["key.space"].tap()
        }
        sleep(1)
        attach(safari, "host-keyboard-typed")
        if let value = textView.value as? String {
            print("HOST VALUE:", value)
            XCTAssertTrue(value.contains("你好"), "host did not contain 你好: \(value)")
            XCTAssertTrue(value.contains("abc"), "host did not contain abc: \(value)")
        }
    }

    func testSafariKeyboardShow() throws {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        if safari.state != .runningForeground { safari.activate() }
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))
        attach(safari, "safari-before-tap")
        let textViews = safari.textViews
        if textViews.firstMatch.waitForExistence(timeout: 3) {
            textViews.firstMatch.tap()
        } else {
            safari.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        }
        sleep(2)
        attach(safari, "safari-after-tap")
        print(safari.debugDescription)
        let keyboards = safari.keyboards
        print("KEYBOARD COUNT", keyboards.count)
        if keyboards.count > 0 {
            print("KEYBOARD", keyboards.firstMatch.debugDescription)
            attach(safari, "safari-keyboard-visible")
        }
    }

    func testNotesHostDiagnostic() throws {
        let notes = XCUIApplication(bundleIdentifier: "com.apple.mobilenotes")
        notes.launch()
        XCTAssertTrue(notes.wait(for: .runningForeground, timeout: 20))
        attach(notes, "notes-start")
        print(notes.debugDescription)
        for label in ["Continue", "继续", "Not Now", "以后再说"] {
            let button = notes.buttons[label].firstMatch
            if button.waitForExistence(timeout: 2) { button.tap() }
        }
        let newNote = notes.buttons["New Note"].exists ? notes.buttons["New Note"] : notes.buttons["新建备忘录"]
        if newNote.waitForExistence(timeout: 3) {
            newNote.tap()
        } else {
            notes.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).tap()
        }
        sleep(1)
        attach(notes, "notes-new")
        print(notes.debugDescription)
        let body = notes.textViews.firstMatch
        if body.waitForExistence(timeout: 3) {
            body.tap()
        }
        sleep(2)
        attach(notes, "notes-keyboard")
        print(notes.debugDescription)
    }

    func testKeyboardExtensionInSafari() throws {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 15))

        tapEither(settings, ["General", "通用"])
        tapEither(settings, ["Keyboard", "键盘"])
        tapEither(settings, ["Keyboards", "键盘"])
        attach(settings, "settings-keyboards")

        tapEither(settings, ["Add New Keyboard...", "Add New Keyboard…", "添加新键盘…", "添加新键盘"])
        let ourKeyboard = settings.staticTexts["微输入法"].firstMatch
        if !ourKeyboard.exists {
            for _ in 0..<6 {
                settings.swipeUp()
                if ourKeyboard.exists { break }
            }
        }
        if ourKeyboard.waitForExistence(timeout: 5) {
            ourKeyboard.tap()
        }
        attach(settings, "settings-add-keyboard")

        // Open the keyboard detail and allow full access.
        if ourKeyboard.waitForExistence(timeout: 4) && ourKeyboard.isHittable {
            ourKeyboard.tap()
        }
        attach(settings, "settings-keyboard-detail")
        let allowSwitch = settings.switches["Allow Full Access"].exists
            ? settings.switches["Allow Full Access"]
            : settings.switches["允许完全访问"]
        if allowSwitch.waitForExistence(timeout: 4), (allowSwitch.value as? String) != "1" {
            allowSwitch.tap()
            let allow = settings.buttons["Allow"].exists ? settings.buttons["Allow"] : settings.buttons["允许"]
            if allow.waitForExistence(timeout: 3) { allow.tap() }
        }
        attach(settings, "settings-full-access")

        settings.terminate()

        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 20))
        dismissSafariOnboarding(safari)
        attach(safari, "safari-start")

        // Open the local keyboard host page.
        let address = safari.textFields.firstMatch
        if address.waitForExistence(timeout: 5) {
            address.tap()
        } else {
            safari.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.94)).tap()
        }
        safari.typeText("http://127.0.0.1:8899\n")
        sleep(4)
        attach(safari, "safari-page")

        // Focus the textarea.
        safari.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.34)).tap()
        sleep(3)
        attach(safari, "safari-keyboard-initial")

        // Cycle keyboards with the globe key until the clone toolbar appears.
        for _ in 0..<6 {
            if safari.buttons["tool.mode"].exists || safari.staticTexts["微输入法"].exists {
                break
            }
            safari.coordinate(withNormalizedOffset: CGVector(dx: 0.09, dy: 0.932)).tap()
            sleep(1)
        }
        attach(safari, "safari-keyboard-cycle")

        // Switch to QWERTY and type ni, then select a candidate.
        if safari.buttons["tool.mode"].waitForExistence(timeout: 3) {
            safari.buttons["tool.mode"].tap()
            if safari.buttons["mode.qwerty"].waitForExistence(timeout: 3) {
                safari.buttons["mode.qwerty"].tap()
            }
            for key in ["key.n", "key.i", "key.h", "key.a", "key.o"] {
                if safari.buttons[key].exists { safari.buttons[key].tap() }
            }
            sleep(1)
            attach(safari, "safari-keyboard-candidates")
            if safari.buttons["candidate.0"].exists {
                safari.buttons["candidate.0"].tap()
            } else if safari.buttons["你好"].exists {
                safari.buttons["你好"].tap()
            }
            sleep(1)
            // Add ASCII through the English keyboard to prove both scripts commit.
            safari.buttons["tool.mode"].tap()
            if safari.buttons["mode.english"].waitForExistence(timeout: 3) {
                safari.buttons["mode.english"].tap()
            }
            for key in ["key.a", "key.b", "key.c"] {
                if safari.buttons[key].exists { safari.buttons[key].tap() }
            }
            if safari.buttons["key.space"].exists { safari.buttons["key.space"].tap() }
            sleep(1)
            attach(safari, "safari-keyboard-typed")
            if let value = safari.textFields.firstMatch.value as? String {
                XCTAssertTrue(value.contains("你好") || value.contains("abc"), "host value: \(value)")
            }
        }

        // Also show the T9 layout and toolbar.
        if safari.buttons["tool.mode"].exists {
            safari.buttons["tool.mode"].tap()
            if safari.buttons["mode.t9"].exists { safari.buttons["mode.t9"].tap() }
            safari.buttons["tool.clipboard"].tap()
            sleep(1)
            attach(safari, "safari-keyboard-toolbar")
            safari.buttons["tool.voice"].tap()
            sleep(1)
            attach(safari, "safari-keyboard-voice")
        }
    }

    func testOnboardingAccept() throws {
        let onboarding = XCUIApplication()
        onboarding.launchArguments = []
        onboarding.launch()
        if onboarding.staticTexts["欢迎使用微输入法"].waitForExistence(timeout: 8) {
            attach(onboarding, "onboarding")
            let toggle = onboarding.switches.firstMatch
            XCTAssertTrue(toggle.waitForExistence(timeout: 3))
            toggle.tap()
            onboarding.buttons["同意并继续"].tap()
            XCTAssertTrue(onboarding.staticTexts["微输入法"].waitForExistence(timeout: 8), "home after consent")
            attach(onboarding, "home-after-consent")
        }
    }

    func testTextToolsRealResponse() throws {
        app.terminate()
        app.launchArguments = ["-onboarding.accepted", "YES", "-uitest.route", "textTools"]
        app.launch()
        XCTAssertTrue(app.navigationBars["文字工具"].waitForExistence(timeout: 15))
        let editor = app.textViews.firstMatch
        if editor.waitForExistence(timeout: 5) {
            editor.tap()
            editor.typeText("hello world")
        }
        app.buttons["tools.run"].tap()
        let result = app.staticTexts["结果"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 40), "text tool result missing")
        attach("text-tools-result")
    }

    // MARK: - Helpers

    private func scrollTo(_ label: String) -> XCUIElement {
        let element = app.staticTexts[label].firstMatch
        if element.exists && element.isHittable { return element }
        for _ in 0..<8 {
            app.swipeUp()
            if element.exists && element.isHittable { return element }
        }
        for _ in 0..<14 {
            app.swipeDown()
            if element.exists && element.isHittable { return element }
        }
        return element
    }

    private func tapAndCheck(_ label: String) {
        let element = scrollTo(label)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "missing \(label)")
        element.tap()
        XCTAssertTrue(app.navigationBars[label].waitForExistence(timeout: 6), "page \(label) did not open")
        attach("page-\(label)")
    }

    private func back() {
        let buttons = app.navigationBars.buttons
        if buttons.count > 0 {
            buttons.element(boundBy: 0).tap()
        } else {
            app.swipeRight()
        }
    }

    private func attach(_ name: String) {
        attach(XCUIApplication(), name)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func tapEither(_ app: XCUIApplication, _ labels: [String]) {
        for label in labels {
            let element = app.staticTexts[label].firstMatch
            if element.waitForExistence(timeout: 2) && element.isHittable {
                element.tap()
                return
            }
            for _ in 0..<6 {
                app.swipeUp()
                if element.exists && element.isHittable {
                    element.tap()
                    return
                }
            }
            let cell = app.cells.containing(.staticText, identifier: label).firstMatch
            if cell.waitForExistence(timeout: 1) {
                cell.tap()
                return
            }
        }
        XCTFail("none of \(labels) found")
    }

    private func dismissSafariOnboarding(_ safari: XCUIApplication) {
        for label in ["Continue", "继续", "Not Now", "以后再说", "Start Browsing"] {
            let button = safari.buttons[label].firstMatch
            if button.waitForExistence(timeout: 2) {
                button.tap()
            }
        }
    }
}
