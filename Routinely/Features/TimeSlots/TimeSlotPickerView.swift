//
//  TimeSlotPickerView.swift
//  Routinely
//
//  Created by Michael Edlund on 2026-03-11.
//

import SwiftUI

struct TimeSlotPickerView: View {
    @Binding var selectedTimeSlot: TimeSlot?
    var onSelect: ((TimeSlot) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeSlot.allCases, id: \.self) { timeSlot in
                    TimeSlotButton(
                        timeSlot: timeSlot,
                        isSelected: selectedTimeSlot == timeSlot
                    ) {
                        selectedTimeSlot = timeSlot
                        onSelect?(timeSlot)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TimeSlotButton: View {
    let timeSlot: TimeSlot
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: timeSlot.defaultIcon)
                    .font(.title2)

                Text(timeSlot.displayName())
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(width: 80, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? timeSlot.swiftUIColor : Color(.secondarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TimeSlotPickerView(selectedTimeSlot: .constant(.morning))
}
