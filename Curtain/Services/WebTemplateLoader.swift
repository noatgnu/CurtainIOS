//
//  WebTemplateLoader.swift
//  Curtain
//
//  Created by Toan Phung on 07/01/2026.
//

import Foundation

enum WebTemplateError: Error {
    case templateNotFound(String)
    case invalidEncoding
}

class WebTemplateLoader {
    static let shared = WebTemplateLoader()

    private init() {}

    func loadHTMLTemplate(named name: String) throws -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "html"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw WebTemplateError.templateNotFound("\(name).html")
        }
        return content
    }

    func loadJavaScript(named name: String) throws -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw WebTemplateError.templateNotFound("\(name).js")
        }
        return content
    }

    func loadCSS(named name: String) throws -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "css"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw WebTemplateError.templateNotFound("\(name).css")
        }
        return content
    }

    func render(template: String, substitutions: [String: String]) -> String {
        var result = template
        for (key, value) in substitutions {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }
}
