//
//  DataSourceFacade+Profile.swift
//  DataSourceFacade+Profile
//
//  Created by Cirno MainasuK on 2021-9-8.
//  Copyright © 2021 Twidere. All rights reserved.
//

import Foundation

extension DataSourceFacade {
    static func coordinateToProfileScene(
        provider: DataSourceProvider,
        target: StatusTarget,
        status: StatusRecord
    ) async {
        let _redirectRecord = await DataSourceFacade.author(
            managedObjectContext: provider.context.managedObjectContext,
            status: status,
            target: target
        )
        guard let redirectRecord = _redirectRecord else {
            assertionFailure()
            return
        }
        let profileViewModel = LocalProfileViewModel(
            context: provider.context,
            userRecord: redirectRecord
        )
        await provider.coordinator.present(
            scene: .profile(viewModel: profileViewModel),
            from: provider,
            transition: .show
        )
    }
}
