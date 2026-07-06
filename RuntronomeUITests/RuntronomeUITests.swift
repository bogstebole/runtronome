//
//  RuntronomeUITests.swift
//  RuntronomeUITests
//
//  Created by Bogdan Stefanovic on 21. 6. 2026..
//

import XCTest

final class RuntronomeUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testLaunchPerformance() throws {
        let app = XCUIApplication()
        app.activate()
        XCUIDevice.shared.press(.home)
        
        let springboardApp = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboardApp/*@START_MENU_TOKEN@*/.images["record.circle"]/*[[".otherElements",".images[\"Screen Recording\"]",".images[\"record.circle\"]",".images"],[[[-1,2],[-1,1],[-1,3],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.firstMatch.tap()
        
        let elementsQuery = springboardApp.otherElements
        elementsQuery/*@START_MENU_TOKEN@*/.containing(.image, identifier: "record.circle").firstMatch/*[[".element(boundBy: 86)",".containing(.image, identifier: \"record.circle\").firstMatch"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.doubleTap()
        
        app.activate()
        app.windows/*@START_MENU_TOKEN@*/.firstMatch/*[[".containing(.other, identifier: nil).firstMatch",".firstMatch"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeUp()
        XCUIDevice.shared.press(.home)
        springboardApp.statusBars/*@START_MENU_TOKEN@*/.containing(.other, identifier: nil).firstMatch/*[[".element(boundBy: 0)",".containing(.staticText, identifier: \"23:14\").firstMatch",".containing(.other, identifier: nil).firstMatch"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeDown()
        springboardApp/*@START_MENU_TOKEN@*/.collectionViews["Route Picker Items"].firstMatch/*[[".otherElements.collectionViews[\"Route Picker Items\"].firstMatch",".collectionViews",".containing(.other, identifier: \"Horizontal scroll bar, 1 page\").firstMatch",".containing(.other, identifier: \"Vertical scroll bar, 1 page\").firstMatch",".firstMatch",".collectionViews[\"Route Picker Items\"].firstMatch"],[[[-1,5],[-1,1,1],[-1,0]],[[-1,4],[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        elementsQuery.element(boundBy: 65).tap()
        
        let element = springboardApp/*@START_MENU_TOKEN@*/.images["record.circle"]/*[[".otherElements[\"regular.view\"].images",".otherElements",".images[\"Screen Recording\"]",".images[\"record.circle\"]"],[[[-1,3],[-1,2],[-1,1,1],[-1,0]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.firstMatch
        element/*@START_MENU_TOKEN@*/.press(forDuration: 0.5)/*[[".tap()",".press(forDuration: 0.5)"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        
        let element2 = elementsQuery.element(boundBy: 70)
        element2.doubleTap()
        element.tap()
        element2.tap()

        app.launch()
    }
}
