//
//  qbremoteUITests.swift
//  qbremoteUITests
//
//  Created by Ryan Cummings on 3/5/26.
//

import XCTest

final class qbremoteUITests: XCTestCase {

    override func setUpWithError() throws {
        // Enforce portrait mode for consistent UI element visibility (especially avoiding keyboard occlusion in landscape).
        // setUpWithError runs on the main thread, so it's safe to access the main-actor-isolated XCUIDevice here.
        MainActor.assumeIsolated {
            XCUIDevice.shared.orientation = .portrait
        }

        continueAfterFailure = false
    }

    @MainActor
    func testTakeScreenshots() throws {
        let app = XCUIApplication()
        
        // Pass launch arguments to use dummy data for screenshots
        app.launchArguments.append("-isUITest")
        app.launchArguments.append("YES")
        app.launchArguments.append("-isDemoMode")
        app.launchArguments.append("YES")
        app.launchArguments.append("-UIUserInterfaceStyle")
        app.launchArguments.append("light")
        app.launchArguments.append("-themePreference")
        app.launchArguments.append("light")
        
        // Setup Fastlane Snapshot
        setupSnapshot(app)
        
        app.launch()

        // 1. Torrent List (Home Screen)
        // Wait for the list to load dummy data (should be fast since it's local, but give it a second)
        sleep(2)
        snapshot("01_TorrentList")

        // 2. Torrent Details
        let torrentRow = app.staticTexts["torrent_name_Ubuntu 24.04 Desktop amd64.iso"]
        if torrentRow.waitForExistence(timeout: 2.0) {
            torrentRow.tap()
            sleep(1)
            snapshot("02_TorrentDetails")
            // Dismiss the sheet
            if app.buttons["Done"].exists {
                app.buttons["Done"].tap()
            } else {
                app.swipeDown(velocity: .fast)
            }
            sleep(1)
        }

        // 3. Server Screen
        // Tap on the "Servers" tab (iPhone) or sidebar item (iPad)
        if UIDevice.current.userInterfaceIdiom == .pad {
            if !app.staticTexts["Servers"].exists {
                let toggleBtn = app.buttons["ToggleSidebar"]
                if toggleBtn.exists {
                    toggleBtn.tap()
                    sleep(1)
                }
            }
            if app.staticTexts["Servers"].exists {
                app.staticTexts["Servers"].firstMatch.tap()
            }
        } else {
            app.tabBars.buttons["Servers"].tap()
        }
        sleep(2)
        snapshot("03_ServerList")
        
        // 4. Server Config
        let configBtn = app.buttons["row_config_button"].firstMatch
        if configBtn.waitForExistence(timeout: 2.0) {
            configBtn.tap()
                sleep(4) // Delay to wait for loading indicator to finish
                snapshot("04_ServerConfig")
                app.buttons["Cancel"].tap()
                sleep(1)
        }

        // 5. Add Torrent Screen
        // Go back to torrents tab
        if UIDevice.current.userInterfaceIdiom == .pad {
            if !app.staticTexts["Torrents"].exists {
                let toggleBtn = app.buttons["ToggleSidebar"]
                if toggleBtn.exists {
                    toggleBtn.tap()
                    sleep(1)
                }
            }
            if app.staticTexts["Torrents"].exists {
                app.staticTexts["Torrents"].firstMatch.tap()
            }
        } else {
            app.tabBars.buttons["Torrents"].tap()
        }
        
        // Tap the add button
         app.buttons["Add Torrent"].tap()
        
        // Wait for sheet to appear
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5.0))
        
        sleep(2)
        snapshot("05_AddTorrent", timeWaitingForIdle: 1.0)
        
        // Graceful exit: tap Cancel instead of executing destructive action or swiping
        app.buttons["Cancel"].tap()
        sleep(1)
    }

    @MainActor
    func testAddTorrentFlow() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments.append("-isUITest")
        app.launchArguments.append("YES")
        app.launchArguments.append("-isDemoMode")
        app.launchArguments.append("NO")
        app.launch()
        
        // 1. Torrents Tab
        if UIDevice.current.userInterfaceIdiom == .pad {
            if app.staticTexts["Torrents"].exists {
                app.staticTexts["Torrents"].firstMatch.tap()
            }
        } else {
            app.tabBars.buttons["Torrents"].tap()
        }
        
        // 2. Tap Add Torrent button
        let addTorrentBtn = app.buttons["Add Torrent"]
        XCTAssertTrue(addTorrentBtn.waitForExistence(timeout: 5.0))
        addTorrentBtn.tap()
        
        // 3. Find the URL text field
        let urlField = app.textFields["magnet_url_field"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 5.0))
        urlField.tap()
        urlField.typeText("https://ubuntu.com/download.torrent")
        
        // 4. Tap 'Add' button
        let addButton = app.buttons["add_torrent_submit_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5.0))
        addButton.tap()
        
        // Wait for sheet to dismiss and new torrent to appear in the list
        // MockQBittorrentAPIService uses lastPathComponent if it's a URL
        let newTorrentRow = app.staticTexts["torrent_name_download.torrent"]
        if !newTorrentRow.waitForExistence(timeout: 5.0) {
            print("DEBUG VIEW HIERARCHY ADD TORRENT FLOW: \n\(app.debugDescription)")
        }
        XCTAssertTrue(newTorrentRow.exists)
    }

    @MainActor
    func testTorrentActionsFlow() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments.append("-isUITest")
        app.launchArguments.append("YES")
        app.launchArguments.append("-isDemoMode")
        app.launchArguments.append("NO")
        app.launch()
        
        // 1. Torrents Tab
        if UIDevice.current.userInterfaceIdiom == .pad {
            if app.collectionViews.buttons["Torrents"].exists {
                app.collectionViews.buttons["Torrents"].tap()
            }
        } else {
            app.tabBars.buttons["Torrents"].tap()
        }
        
        // 2. Tap on a torrent row
        let torrentRow = app.staticTexts["torrent_name_Ubuntu 24.04 Desktop amd64.iso"]
        if !torrentRow.waitForExistence(timeout: 5.0) {
            print("DEBUG VIEW HIERARCHY ACTIONS FLOW: \n\(app.debugDescription)")
        }
        XCTAssertTrue(torrentRow.exists)
        torrentRow.tap()
        
        // 3. Tap pause button
        // The Actions section might be off-screen on smaller devices, so scroll down first
        app.swipeUp()
        let pauseBtn = app.buttons["pause_torrent_button"]
        XCTAssertTrue(pauseBtn.waitForExistence(timeout: 5.0))
        pauseBtn.tap()
        
        // 4. Since pause dismisses the sheet, wait to be back on the list
        XCTAssertTrue(torrentRow.waitForExistence(timeout: 5.0))
    }
    
    @MainActor
    func testAddServerFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-isUITest")
        app.launchArguments.append("YES")
        app.launchArguments.append("-isDemoMode")
        app.launchArguments.append("NO")
        app.launch()
        
        // Navigate to Servers tab
        if UIDevice.current.userInterfaceIdiom == .pad {
            if app.staticTexts["Servers"].exists {
                app.staticTexts["Servers"].firstMatch.tap()
            }
        } else {
            app.tabBars.buttons["Servers"].tap()
        }
        
        // Tap Add Server button
        let addServerButton = app.buttons["add_server_button"]
        if !addServerButton.waitForExistence(timeout: 5.0) {
            print("DEBUG HIERARCHY: \(app.debugDescription)")
        }
        XCTAssertTrue(addServerButton.exists)
        addServerButton.tap()
        
        // Fill out the form
        let nameField = app.textFields["server_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5.0))
        nameField.tap()
        nameField.typeText("UI Test Server")
        
        let hostField = app.textFields["server_host_field"]
        hostField.tap()
        hostField.typeText("127.0.0.1")
        
        let portField = app.textFields["server_port_field"]
        portField.tap()
        portField.typeText("8080")
        
        // Test connection
        let testConnectionButton = app.buttons["test_connection_button"]
        testConnectionButton.tap()
        
        // Wait for success indicator (mock service returns success instantly)
        let successText = app.staticTexts["Connected successfully!"]
        XCTAssertTrue(successText.waitForExistence(timeout: 5.0))
        
        // Save server
        let saveButton = app.buttons["save_server_button"]
        saveButton.tap()
        
        // Verify we returned to the list and the new server is present
        let newServerRow = app.staticTexts["UI Test Server"]
        XCTAssertTrue(newServerRow.waitForExistence(timeout: 5.0))
    }
}
