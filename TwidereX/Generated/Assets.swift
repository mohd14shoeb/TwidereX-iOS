// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ColorAsset.Color", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetColorTypeAlias = ColorAsset.Color
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal static let accentColor = ColorAsset(name: "AccentColor")
  internal enum Arrows {
    internal static let arrowTurnUpLeft = ImageAsset(name: "Arrows/arrow.turn.up.left")
    internal static let arrowTurnUpLeftLarge = ImageAsset(name: "Arrows/arrow.turn.up.left.large")
    internal static let tablerChevronDown = ImageAsset(name: "Arrows/tabler.chevron.down")
  }
  internal enum Colors {
    internal static let heartPink = ColorAsset(name: "Colors/heart.pink")
    internal static let hightLight = ColorAsset(name: "Colors/hight.light")
  }
  internal enum Editing {
    internal static let featherPen = ImageAsset(name: "Editing/feather.pen")
    internal static let xmark = ImageAsset(name: "Editing/xmark")
  }
  internal enum Health {
    internal static let heartFill = ImageAsset(name: "Health/heart.fill")
    internal static let heartFillLarge = ImageAsset(name: "Health/heart.fill.large")
    internal static let heart = ImageAsset(name: "Health/heart")
    internal static let heartLarge = ImageAsset(name: "Health/heart.large")
  }
  internal enum Media {
    internal static let `repeat` = ImageAsset(name: "Media/repeat")
    internal static let repeatLarge = ImageAsset(name: "Media/repeat.large")
  }
  internal enum ObjectTools {
    internal static let icBaselineInsertLink = ImageAsset(name: "Object&Tools/ic.baseline.insert.link")
    internal static let icBaselinePhotoLibrary = ImageAsset(name: "Object&Tools/ic.baseline.photo.library")
    internal static let icRoundLocationOn = ImageAsset(name: "Object&Tools/ic.round.location.on")
    internal static let icRoundRefresh = ImageAsset(name: "Object&Tools/ic.round.refresh")
    internal static let lock = ImageAsset(name: "Object&Tools/lock")
    internal static let paperplane = ImageAsset(name: "Object&Tools/paperplane")
    internal static let share = ImageAsset(name: "Object&Tools/share")
    internal static let shareLarge = ImageAsset(name: "Object&Tools/share.large")
    internal static let uilDocumentLayoutLeft = ImageAsset(name: "Object&Tools/uil.document.layout.left")
  }
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal final class ColorAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Color = NSColor
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Color = UIColor
  #endif

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  internal private(set) lazy var color: Color = {
    guard let color = Color(asset: self) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }()

  fileprivate init(name: String) {
    self.name = name
  }
}

internal extension ColorAsset.Color {
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, *)
  convenience init?(asset: ColorAsset) {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSColor.Name(asset.name), bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Image = UIImage
  #endif

  internal var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let name = NSImage.Name(self.name)
    let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
}

internal extension ImageAsset.Image {
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init?(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = BundleToken.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    Bundle(for: BundleToken.self)
  }()
}
// swiftlint:enable convenience_type
