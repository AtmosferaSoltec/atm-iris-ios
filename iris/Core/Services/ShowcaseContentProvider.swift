//
//  ShowcaseContentProvider.swift
//  iris
//

import Foundation

/// Supplies sample projected content for marketing and onboarding surfaces.
protocol ShowcaseContentProvider {
    func items() -> [ShowcaseItem]
}
