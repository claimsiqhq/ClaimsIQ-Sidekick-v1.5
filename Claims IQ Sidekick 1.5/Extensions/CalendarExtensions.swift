//
//  CalendarExtensions.swift
//  Claims IQ Sidekick 1.5
//
//  Created on 2025-11-11.
//

import Foundation

extension Calendar {
    func startOfDay(for date: Date) -> Date {
        return self.dateInterval(of: .day, for: date)?.start ?? date
    }
}
