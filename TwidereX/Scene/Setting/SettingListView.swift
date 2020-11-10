//
//  SettingListView.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-10.
//  Copyright © 2020 Twidere. All rights reserved.
//

import SwiftUI

struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 14, *) {
                AnyView(content.textCase(.none))
            } else {
                content
            }
        }
    }
}

enum SettingListEntryType: Hashable {
    case appearance
    case display
    case layout
    case webBrowser
    case about
    
    var image: Image {
        switch self {
        case .appearance:       return Image(uiImage: Asset.ObjectTools.clothes.image)
        case .display:          return Image(uiImage: Asset.TextFormatting.textHeaderRedaction.image)
        case .layout:           return Image(uiImage: Asset.sidebarLeft.image)
        case .webBrowser:       return Image(uiImage: Asset.window.image)
        case .about:            return Image(uiImage: Asset.Indices.infoCircle.image)

        }
    }
    
    var title: String {
        switch self {
        case .appearance:       return "Appearance"
        case .display:          return "Display"
        case .layout:           return "Layout"
        case .webBrowser:       return "Web Browser"
        case .about:            return "About"

        }
    }
}

struct SettingListEntry: Identifiable {
    var id: SettingListEntryType { return type }
    let type: SettingListEntryType
    let image: Image
    let title: String
}

struct SettingListEntryRow: View {
    
    let icon: Image
    let title: String
    
    var body: some View {
        HStack {
            icon
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
        }
    }
}

struct SettingListView: View {
    
    @EnvironmentObject var context: AppContext
    
    static let generalSection: [SettingListEntry] = {
        let types: [SettingListEntryType]  = [
            .appearance,
            .display,
            .layout,
            .webBrowser
        ]
        return types.map { type in
            return SettingListEntry(type: type, image: type.image, title: type.title)
        }
    }()
    
    static let aboutSection: [SettingListEntry] = {
        let types: [SettingListEntryType]  = [
            .about,
        ]
        return types.map { type in
            return SettingListEntry(type: type, image: type.image, title: type.title)
        }
    }()
    
    var body: some View {
        List {
            Section(header: Text(verbatim: "General")) {
                ForEach(SettingListView.generalSection) { entry in
                    Button(action: {
                        context.viewStateStore.settingView.presentSettingListEntryPublisher.send(entry)
                    }, label: {
                        SettingListEntryRow(icon: entry.image, title: entry.title)
                            .foregroundColor(Color(.label))
                    })
                }
            }
            .modifier(SectionHeaderStyle())
            Section(header: Text(verbatim: "About")) {
                ForEach(SettingListView.aboutSection) { entry in
                    Button(action: {
                        print("Tapped!")
                    }, label: {
                        SettingListEntryRow(icon: entry.image, title: entry.title)
                            .foregroundColor(Color(.label))
                    })                }
            }
            .modifier(SectionHeaderStyle())
        }
        .listStyle(GroupedListStyle())
    }
    
}

#if DEBUG

struct SettingListView_Previews: PreviewProvider {
    static var previews: some View {
        SettingListView()
    }
}

#endif

