//
//  TranslationServicePreferenceView.swift
//  TwidereX
//
//  Created by MainasuK on 2022-4-1.
//  Copyright © 2022 Twidere. All rights reserved.
//

import os.log
import Foundation
import SwiftUI
import TwidereCommon

struct TranslationServicePreferenceView: View {
    
    let logger = Logger(subsystem: "TranslationServicePreferenceView", category: "View")
    
    var preference: UserDefaults.TranslationServicePreference
        
    var body: some View {
        List {
            ForEach(UserDefaults.TranslationServicePreference.allCases, id: \.rawValue) { preference in
                Button {
                    UserDefaults.shared.translationServicePreference = preference
                    logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): update TranslationServicePreference: \(preference.text)")
                } label: {
                    HStack {
                        Text(preference.text)
                        if self.preference == preference {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .tint(Color(uiColor: .label))
            }   // end ForEach
        }
        .navigationBarTitle(Text(L10n.Scene.Settings.Appearance.Translation.service))
    }   // end body
    
}

#if DEBUG
// Note:
// Preview cannot update the selection due to the UserDefaults value not bind to the Preference
struct TranslationServicePreferenceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TranslationServicePreferenceView(preference: .google)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
