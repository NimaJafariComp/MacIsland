//
//  TabSelectionView.swift
//  boringNotch
//
//  Created by Hugo Persson on 2024-08-25.
//

import SwiftUI

struct TabModel: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let view: NotchViews
}

let tabs = [
    TabModel(label: "Home", icon: "house.fill", view: .home),
    TabModel(label: "Mirror", icon: "camera", view: .mirror),
    TabModel(label: "Shelf", icon: "tray.fill", view: .shelf),
    TabModel(label: "Snippets", icon: "doc.on.clipboard", view: .clipboard),
    TabModel(label: "Notes", icon: "note.text", view: .notes)
]

struct TabSelectionView: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @EnvironmentObject private var vm: BoringViewModel
    @Namespace var animation
    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                    TabButton(
                        label: tab.label,
                        icon: tab.icon,
                        selected: coordinator.currentView == tab.view,
                        width: 30
                    ) {
                        vm.selectOpenPage(tab.view)
                    }
                    .accessibilityIdentifier("macisland.tab.\(tab.label.lowercased())")
                    .frame(height: IslandStyle.minimumHitTarget)
                    .foregroundStyle(tab.view == coordinator.currentView ? Color.islandPrimaryText : Color.islandSecondaryText)
                    .background {
                        if tab.view == coordinator.currentView {
                            Capsule()
                                .fill(Color.islandPressedSurface)
                                .matchedGeometryEffect(id: "capsule", in: animation)
                        }
                    }
            }
        }
        .padding(.horizontal, 2)
        .frame(height: IslandStyle.headerControlHeight)
        .background(Color.islandModuleSurface, in: Capsule())
        .overlay {
            Capsule().stroke(Color.islandModuleBorder, lineWidth: IslandStyle.hairlineWidth)
        }
        .clipShape(Capsule())
    }
}

#Preview {
    BoringHeader().environmentObject(BoringViewModel())
}
