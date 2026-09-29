//
//  ZXToolsTests.swift
//  ZXToolsTests
//
//  Created by ZX on 2026/9/23.
//

import Testing
@testable import ZXTools

struct ZXToolsTests {

    @Test func onlyCompleteWebAddressesAreLinks() {
        #expect(webURL(from: "https://example.com/path?size=2") != nil)
        #expect(webURL(from: "http://localhost:8080/image.png") != nil)
        for text in ["frontend", "json", "tools", "2026-04-21T22:00:00+08:00",
                     "example.com/image.png", "/images/photo.png", "mailto:me@example.com",
                     "javascript:alert(1)", "https://", " https://example.com",
                     "https://example.com/foo bar"] {
            #expect(webURL(from: text) == nil)
        }
    }

    @Test func imagePreviewOnlyForImageWebAddresses() {
        #expect(isImageURLString("https://example.com/photo.png?size=2"))
        #expect(!isImageURLString("https://example.com/page"))
        #expect(!isImageURLString("photo.png"))
        #expect(!isImageURLString("https://example.com/photo.png extra"))
    }

}
