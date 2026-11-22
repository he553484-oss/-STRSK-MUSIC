import XCTest

@MainActor
final class LumaUITests: XCTestCase {
    func testAuthorizedWebDAVMusicPlaysWithImportedKaraoke() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-state"]
        let share = "http://localhost:8181/Music/"
        app.launchEnvironment["STRSK_TEST_WEBDAV_ADDRESS"] = share
        app.launchEnvironment["STRSK_TEST_WEBDAV_USERNAME"] = "listener"
        app.launchEnvironment["STRSK_TEST_WEBDAV_PASSWORD"] = "correct-horse"
        app.launch()
        let entry = app.buttons["library.webdav"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()

        let address = app.textFields["webdav.address"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        XCTAssertEqual(address.value as? String, share)
        app.buttons["webdav.connect"].tap()

        let artist = app.buttons["webdav.artist.Signal Choir"]
        guard artist.waitForExistence(timeout: 25) else {
            let labels = app.alerts.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " · ")
            XCTFail("WebDAV catalog did not open. \(labels)")
            return
        }
        capture(app, name: "M6 WebDAV · real catalog")
        artist.tap()
        XCTAssertTrue(app.buttons["Download and play Quiet Vector"].waitForExistence(timeout: 5))
        app.buttons["Show entire catalog"].tap()
        app.buttons["webdav.album.Night Transmission"].tap()
        let audio = app.buttons["Download and play Signal Archive"]
        XCTAssertTrue(audio.waitForExistence(timeout: 5))
        audio.tap()

        let lyrics = app.buttons["player.lyrics"]
        XCTAssertTrue(lyrics.waitForExistence(timeout: 12))
        XCTAssertEqual(app.buttons["player.playPause"].label, "Pause")
        lyrics.tap()
        XCTAssertTrue(app.staticTexts["Word-synced lyrics"].waitForExistence(timeout: 8))
        let transport = app.buttons["lyrics.playPause"]
        transport.tap()
        XCTAssertEqual(transport.label, "Play lyrics track")
        let line = app.buttons["Follow the signal, seek to 0:18"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        line.tap()
        XCTAssertEqual(line.value as? String, "Singing")
        XCTAssertEqual(transport.label, "Play lyrics track")
        capture(app, name: "M6 WebDAV · karaoke with paused seek")
    }

    func testImportedKaraokeFollowsAudioDuringPlaybackPauseAndSeek() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-state", "--import-strsk-karaoke"]
        app.launch()

        let mini = app.buttons["Open now playing"]
        XCTAssertTrue(mini.waitForExistence(timeout: 16))
        mini.tap()
        let lyrics = app.buttons["player.lyrics"]
        XCTAssertTrue(lyrics.waitForExistence(timeout: 8))
        lyrics.tap()
        XCTAssertTrue(app.staticTexts["Word-synced lyrics"].waitForExistence(timeout: 12))

        let first = app.buttons["Signals through the wire, seek to 0:00"]
        let second = app.buttons["After the quiet, seek to 0:24"]
        let control = app.buttons["lyrics.playPause"]
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        first.tap()
        if control.label == "Play lyrics track" { control.tap() }
        XCTAssertEqual(control.label, "Pause lyrics track")
        XCTAssertEqual(first.value as? String, "Singing")
        capture(app, name: "M5 Karaoke · progressive fill")

        control.tap()
        XCTAssertEqual(control.label, "Play lyrics track")
        XCTAssertTrue(second.waitForExistence(timeout: 6))
        second.tap()
        XCTAssertEqual(control.label, "Play lyrics track")
        XCTAssertEqual(second.value as? String, "Singing")
        capture(app, name: "M5 Karaoke · paused seek")
        let instrumental = app.buttons["Instrumental, seek to 0:38"]
        if !instrumental.isHittable { app.swipeUp() }
        XCTAssertTrue(instrumental.waitForExistence(timeout: 6))
        instrumental.tap()
        XCTAssertTrue(app.staticTexts["Instrumental"].firstMatch.waitForExistence(timeout: 5))
        capture(app, name: "M5 Karaoke · instrumental")
    }

    func testSTRSKAlbumOpensAndPlaysFromItsTrackList() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["STRSK MUSIC"].waitForExistence(timeout: 10))
        capture(app, name: "STRSK Listen")

        app.tabBars.buttons["Library"].tap()
        let albums = app.buttons["Albums"]
        XCTAssertTrue(albums.waitForExistence(timeout: 5))
        albums.tap()
        let album = app.buttons["Open album Somewhere, nowhere"]
        XCTAssertTrue(album.waitForExistence(timeout: 5))
        capture(app, name: "STRSK Library")
        album.tap()

        XCTAssertTrue(app.navigationBars["Somewhere, nowhere"].waitForExistence(timeout: 5))
        let track = app.buttons["Play Golden Hour by Luma Sessions"]
        XCTAssertTrue(track.waitForExistence(timeout: 5))
        capture(app, name: "STRSK Album")
        track.tap()

        XCTAssertTrue(app.buttons["player.playPause"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Golden Hour"].exists)
        XCTAssertEqual(app.buttons["player.playPause"].label, "Pause")
        capture(app, name: "STRSK Now Playing")

        app.buttons["Close now playing"].tap()
        XCTAssertTrue(app.buttons["Open now playing"].waitForExistence(timeout: 5))
    }

    func testReadmeScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-state", "--readme-screenshots", "--mock-lyrics-api"]
        app.launch()
        XCTAssertTrue(app.buttons["Player settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recently played"].exists)
        capture(app, name: "README Listen")
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Play Blue Hour by Mira Vale"].waitForExistence(timeout: 5))
        capture(app, name: "README Library")
        app.buttons["Open now playing"].tap()
        XCTAssertTrue(app.staticTexts["Silver Coast"].waitForExistence(timeout: 5))
        app.buttons["player.playPause"].tap()
        XCTAssertEqual(app.buttons["player.playPause"].label, "Pause")
        capture(app, name: "README Now Playing")
        app.buttons["player.playPause"].tap()
        app.buttons["Close now playing"].tap()
        app.tabBars.buttons["Playlists"].tap()
        app.buttons["Open playlist Night Drive"].tap()
        XCTAssertTrue(app.buttons["Play Silver Coast by Mira Vale"].waitForExistence(timeout: 5))
        capture(app, name: "README Playlist")
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["insights.plays"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(app.staticTexts["insights.plays"].label, "0")
        capture(app, name: "README Insights")
        app.buttons["Open now playing"].tap()
        XCTAssertTrue(app.otherElements["player.visualizer"].waitForExistence(timeout: 5))
        capture(app, name: "README Visualizer")
        app.buttons["player.queue"].tap()
        XCTAssertTrue(app.navigationBars["Play queue"].waitForExistence(timeout: 5))
        capture(app, name: "README Queue")
        app.buttons["Done"].tap()
        app.buttons["player.next"].tap()
        app.buttons["player.next"].tap()
        XCTAssertTrue(app.staticTexts["Late Signal"].waitForExistence(timeout: 5))
        capture(app, name: "README Cool Artwork")
        app.buttons["Close now playing"].tap()
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Play Late Signal by Northline"].waitForExistence(timeout: 5))
        capture(app, name: "README Cool Library")
        app.buttons["Open now playing"].tap()
        app.buttons["player.lyrics"].tap()
        XCTAssertTrue(app.buttons["lyrics.findOnline"].waitForExistence(timeout: 5))
        app.buttons["lyrics.findOnline"].tap()
        XCTAssertTrue(app.buttons["lyrics.search"].waitForExistence(timeout: 5))
        app.buttons["lyrics.search"].tap()
        let result = app.buttons["lyrics.result.42"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        capture(app, name: "README Online Lyrics")
        result.tap()
        XCTAssertTrue(app.navigationBars["Preview lyrics"].waitForExistence(timeout: 5))
        capture(app, name: "README Lyrics Preview")
    }

    func testLibrarySelectionAddsMultipleSongsToNewAndExistingPlaylist() throws {
        let app = launch()
        app.tabBars.buttons["Library"].tap()
        app.buttons["library.options"].tap()
        app.buttons["Select songs"].tap()
        XCTAssertFalse(app.buttons["library.addSelectedToPlaylist"].isEnabled)
        app.buttons["library.select.golden"].tap()
        app.buttons["library.select.blue"].tap()
        app.buttons["library.addSelectedToPlaylist"].tap()
        app.buttons["playlistPicker.done"].tap()
        XCTAssertEqual(app.buttons["library.select.golden"].value as? String, "Selected")
        app.buttons["library.addSelectedToPlaylist"].tap()
        app.buttons["New playlist"].tap()
        let name = app.textFields["playlist.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        enter("Selected songs", in: name, app: app)
        app.buttons["playlist.save"].tap()
        XCTAssertTrue(app.buttons["library.options"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Playlists"].tap()
        app.buttons["Open playlist Selected songs"].tap()
        XCTAssertTrue(app.buttons["Play Golden Hour by Luma Sessions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Play Weightless by Luma Sessions"].exists)
        XCTAssertFalse(app.buttons["Play Afterglow by Luma Sessions"].exists)
        app.tabBars.buttons["Library"].tap()
        app.buttons["library.options"].tap()
        app.buttons["Select songs"].tap()
        app.buttons["library.selectAll"].tap()
        app.buttons["library.addSelectedToPlaylist"].tap()
        app.buttons["Add to Selected songs"].tap()
        XCTAssertTrue(app.buttons["library.options"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.tabBars.buttons["Playlists"].tap()
        app.buttons["Open playlist Selected songs"].tap()
        XCTAssertTrue(app.buttons["Play Afterglow by Luma Sessions"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "Play Golden Hour by Luma Sessions").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "Play Weightless by Luma Sessions").count, 1)
    }

    func testGenreYearFiltersAndQualityDetails() throws {
        let app = launch()
        app.tabBars.buttons["Library"].tap()
        app.buttons["library.genreFilter"].tap()
        app.buttons["Jazz"].tap()
        XCTAssertTrue(app.buttons["Play Weightless by Luma Sessions"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Play Golden Hour by Luma Sessions"].exists)
        app.buttons["Clear filters"].tap()
        app.buttons["library.yearFilter"].tap()
        app.buttons["2024"].tap()
        XCTAssertTrue(app.buttons["Play Golden Hour by Luma Sessions"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Play Weightless by Luma Sessions"].exists)
        app.buttons["Open now playing"].tap()
        app.buttons["Audio quality and output details"].tap()
        for _ in 0..<3 where !app.staticTexts["Source bit depth"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Source bit depth"].waitForExistence(timeout: 5))
        for _ in 0..<3 where !app.staticTexts["Actual sample rate"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Actual sample rate"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    func testSelectMultipleDeleteAndDeleteAllWithCancellation() throws {
        let app = launch()
        app.tabBars.buttons["Library"].tap()
        app.buttons["library.options"].tap()
        app.buttons["Select songs"].tap()
        XCTAssertFalse(app.buttons["library.deleteSelected"].isEnabled)
        app.buttons["library.selectAll"].tap()
        XCTAssertEqual(app.buttons["library.select.golden"].value as? String, "Selected")
        app.buttons["library.select.golden"].tap()
        app.buttons["library.deleteSelected"].tap()
        XCTAssertTrue(app.buttons["Delete 2 songs"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["library.select.blue"].exists)
        app.buttons["library.deleteSelected"].tap()
        app.buttons["Delete 2 songs"].tap()
        XCTAssertTrue(app.buttons["Play Golden Hour by Luma Sessions"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Play Weightless by Luma Sessions"].exists)
        app.buttons["library.options"].tap()
        app.buttons["Delete all songs"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Play Golden Hour by Luma Sessions"].exists)
        app.buttons["library.options"].tap()
        app.buttons["Delete all songs"].tap()
        app.buttons["Delete 1 song"].tap()
        XCTAssertTrue(app.staticTexts["No music"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Open now playing"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.staticTexts["No music"].waitForExistence(timeout: 5))
    }

    func testFreshInstallHasNoStarterMusicOrSlogans() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-state"]
        app.launch()
        XCTAssertTrue(app.staticTexts["No music"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Open now playing"].exists)
        XCTAssertFalse(app.staticTexts["Find your\nfrequency."].exists)
        capture(app, name: "Luma Empty Library")
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["No music"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Play Golden Hour by Luma Sessions"].exists)
        XCTAssertFalse(app.staticTexts["Your own little\nuniverse."].exists)
        app.tabBars.buttons["Playlists"].tap()
        XCTAssertTrue(app.staticTexts["No playlists"].waitForExistence(timeout: 5))
    }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-state", "--seed-test-library"]
        app.launch()
        return app
    }
    private func enter(_ text: String, in field: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let keyboard = app.keyboards.firstMatch
        field.tap()
        if !keyboard.waitForExistence(timeout: 2) {
            field.tap()
        }
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        field.typeText(text)
        if let entered = field.value as? String, !entered.isEmpty, entered != text, text.hasPrefix(entered) {
            // The simulator can drop keystrokes while the keyboard finishes animating.
            field.typeText(String(text.dropFirst(entered.count)))
        }
        XCTAssertEqual(field.value as? String, text, "The simulator must enter the intended text before submission.")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testOriginalArtworkAndAlbumTintFollowTrackChanges() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-state", "--color-artwork-fixture"]
        app.launch()
        app.buttons["Open now playing"].tap()
        XCTAssertTrue(app.staticTexts["Amber"].waitForExistence(timeout: 5))
        capture(app, name: "Luma Amber Artwork")
        app.buttons["player.next"].tap()
        XCTAssertTrue(app.staticTexts["Cobalt"].waitForExistence(timeout: 5))
        app.buttons["player.playPause"].tap()
        capture(app, name: "Luma Cobalt Artwork")
        app.buttons["Close now playing"].tap()
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Play Amber by Artwork test"].waitForExistence(timeout: 5))
        capture(app, name: "Luma Color Library")
        app.buttons["Play Amber by Artwork test"].tap()
        XCTAssertTrue(app.staticTexts["player.header"].waitForExistence(timeout: 5))
        app.buttons["player.playPause"].tap()
    }

    func testOnlineLyricsPreviewReplaceAndOfflinePersistence() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-state", "--seed-test-library", "--mock-lyrics-api"]
        app.launch()
        app.buttons["Open now playing"].tap()
        app.buttons["player.lyrics"].tap()
        app.buttons["lyrics.add"].tap()
        let editor = app.textViews["lyrics.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        enter("My existing lyrics", in: editor, app: app)
        app.buttons["lyrics.save"].tap()
        app.buttons["Lyrics options"].tap()
        app.buttons["lyrics.findOnline"].tap()
        XCTAssertTrue(app.textFields["lyrics.searchTitle"].waitForExistence(timeout: 5))
        app.buttons["lyrics.search"].tap()
        let result = app.buttons["lyrics.result.42"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        capture(app, name: "Luma Online Lyrics")
        result.tap()
        XCTAssertTrue(app.navigationBars["Preview lyrics"].waitForExistence(timeout: 5))
        capture(app, name: "Luma Lyrics Preview")
        app.buttons["lyrics.downloadSave"].tap()
        XCTAssertTrue(app.buttons["Replace lyrics"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Preview lyrics"].exists)
        app.buttons["lyrics.downloadSave"].tap()
        app.buttons["Replace lyrics"].tap()
        XCTAssertTrue(app.buttons["Silver light upon the water, seek to 0:00"].waitForExistence(timeout: 5))
        app.terminate()
        // No mock API or network lookup is needed to read the saved lyrics.
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["Open now playing"].tap()
        app.buttons["player.lyrics"].tap()
        XCTAssertTrue(app.buttons["Silver light upon the water, seek to 0:00"].waitForExistence(timeout: 5))
    }

    func testPlaybackLyricsRepeatShuffleAndSearch() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["STRSK MUSIC"].waitForExistence(timeout: 10))
        capture(app, name: "Luma Listen")
        app.buttons["Open now playing"].tap()
        XCTAssertTrue(app.staticTexts["player.header"].waitForExistence(timeout: 5))
        let visualizer = app.otherElements["player.visualizer"]
        XCTAssertTrue(visualizer.waitForExistence(timeout: 5))
        XCTAssertEqual(visualizer.value as? String, "Paused")
        app.buttons["player.playPause"].tap()
        XCTAssertEqual(app.buttons["player.playPause"].label, "Pause")
        XCTAssertEqual(visualizer.value as? String, "Live audio")
        capture(app, name: "Luma Visualizer")
        app.buttons["player.next"].tap()
        XCTAssertTrue(app.staticTexts["Weightless"].exists)
        app.buttons["Add to favorites"].tap()
        XCTAssertTrue(app.buttons["Remove from favorites"].exists)
        app.buttons["player.repeat"].tap()
        XCTAssertEqual(app.buttons["player.repeat"].label, "Repeat all")
        app.buttons["player.repeat"].tap()
        XCTAssertEqual(app.buttons["player.repeat"].label, "Repeat one")
        app.buttons["player.shuffle"].tap()
        XCTAssertEqual(app.buttons["player.shuffle"].value as? String, "On")
        capture(app, name: "Luma Now Playing")
        app.buttons["player.playPause"].tap()
        XCTAssertEqual(visualizer.value as? String, "Paused")
        app.buttons["player.visualizerToggle"].tap()
        XCTAssertTrue(visualizer.waitForNonExistence(timeout: 2))
        app.buttons["player.queue"].tap()
        XCTAssertTrue(app.navigationBars["Play queue"].waitForExistence(timeout: 5))
        capture(app, name: "Luma Queue")
        app.buttons["Done"].tap()
        app.buttons["player.lyrics"].tap()
        XCTAssertTrue(app.buttons["lyrics.add"].waitForExistence(timeout: 5))
        app.buttons["lyrics.add"].tap()
        let editor = app.textViews["lyrics.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("[00:00.00]First line\n[00:10.00]Second line")
        app.buttons["lyrics.save"].tap()
        XCTAssertTrue(app.buttons["First line, seek to 0:00"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["player.settings"].tap()
        app.buttons["sleep.15"].tap()
        for _ in 0..<3 where !app.buttons["sleep.cancel"].exists { app.swipeUp() }
        XCTAssertTrue(app.buttons["sleep.cancel"].exists)
        app.buttons["sleep.cancel"].tap()
        app.buttons["Done"].tap()
        app.buttons["Close now playing"].tap()
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["Import your music"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Search"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        enter("Afterglow", in: search, app: app)
        XCTAssertTrue(app.buttons["Play Afterglow by Luma Sessions"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Play Golden Hour by Luma Sessions"].exists)
    }

    func testPlaylistCreationAddingTracksAndPersistence() throws {
        let app = launch()
        app.tabBars.buttons["Playlists"].tap()
        app.buttons["playlist.create"].tap()
        let name = app.textFields["playlist.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        enter("Night Drive", in: name, app: app)
        app.buttons["playlist.save"].tap()
        let playlist = app.buttons["Open playlist Night Drive"]
        XCTAssertTrue(playlist.waitForExistence(timeout: 5))
        playlist.tap()
        app.buttons["playlist.addMusic"].tap()
        app.buttons["Select Golden Hour"].tap()
        app.buttons["Select Weightless"].tap()
        app.buttons["playlist.confirmAdd"].tap()
        XCTAssertTrue(app.buttons["Play Golden Hour by Luma Sessions"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Play Weightless by Luma Sessions"].exists)
        capture(app, name: "Luma Playlist")
        app.swipeDown()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        enter("Weightless", in: search, app: app)
        XCTAssertTrue(app.buttons["Play Weightless by Luma Sessions"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Play Golden Hour by Luma Sessions"].exists)
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.tabBars.buttons["Playlists"].tap()
        XCTAssertTrue(app.buttons["Open playlist Night Drive"].waitForExistence(timeout: 5))
        app.buttons["Open playlist Night Drive"].tap()
        XCTAssertTrue(app.buttons["Play Golden Hour by Luma Sessions"].exists)
    }

    func testInsightsShowActualListeningAndUnplayedTracks() throws {
        let app = launch()
        app.buttons["mini.playPause"].tap()
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.navigationBars["Playback Insights"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["insights.plays"].exists)
        XCTAssertEqual(app.staticTexts["insights.plays"].label, "0")
        capture(app, name: "Luma Insights")
        app.swipeUp()
        let least = app.buttons["insights.leastPlayed"]
        XCTAssertTrue(least.waitForExistence(timeout: 5))
        least.tap()
        XCTAssertTrue(app.staticTexts["Unplayed"].firstMatch.exists)
        app.buttons["mini.playPause"].tap()
    }
}
