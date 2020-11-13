//
//  UIApplication.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-11-13.
//  Copyright © 2020 Twidere. All rights reserved.
//

import UIKit

extension UIApplication {

    class func appVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }

    class func appBuild() -> String {
        return Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
    }

    class func versionBuild() -> String {
        let version = appVersion(), build = appBuild()

        return version == build ? "v\(version)" : "v\(version) (\(build))"
    }

}
