//
//  MemorySection.swift
//  Cloude
//

import Foundation

struct MemorySection: Codable, Identifiable {
    var id: String { title }
    let title: String
    let content: String
}
