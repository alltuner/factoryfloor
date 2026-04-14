// ABOUTME: Shared design tokens for the Factory Floor UI.
// ABOUTME: Single source of truth for spacing, radii, opacity, typography, animation, and colors.

import SwiftUI

enum FFDesign {
    // MARK: - Spacing (4pt baseline grid)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 20
        static let xxxl: CGFloat = 24
    }

    // MARK: - Corner Radii

    enum Radii {
        /// Inline badges, status indicators, icon buttons
        static let small: CGFloat = 4
        /// Tabs, banners, action buttons, cards
        static let medium: CGFloat = 6
        /// Project icons, drop overlays, sheet cards
        static let large: CGFloat = 10
    }

    // MARK: - Opacity

    enum Opacity {
        /// Light background hint on hover
        static let hoverSubtle: Double = 0.04
        /// Normal interactive hover
        static let hover: Double = 0.08
        /// Selected but not focused
        static let selectionSubtle: Double = 0.12
        /// Focused selection
        static let selection: Double = 0.15
    }

    // MARK: - Typography

    enum Typography {
        /// 22pt bold — task descriptions, project names in hero sections
        static let heroTitle: Font = .system(size: 22, weight: .bold)
        /// 14pt semibold — section headers
        static let sectionHeader: Font = .system(size: 14, weight: .semibold)
        /// System body — list items, form labels
        static let body: Font = .body
        /// System body medium — project names in sidebar
        static let bodyMedium: Font = .system(.body, weight: .medium)
        /// System body monospaced — branch names in form rows
        static let bodyMono: Font = .system(.body, design: .monospaced)
        /// 13pt — secondary labels
        static let label: Font = .system(size: 13)
        /// 12pt — tab labels, file names, toolbar items
        static let detail: Font = .system(size: 12)
        /// 12pt medium — file names in Changes list
        static let detailMedium: Font = .system(size: 12, weight: .medium)
        /// 11pt — secondary info in tabs, PR badges
        static let caption: Font = .system(size: 11)
        /// 11pt medium — badge labels
        static let captionMedium: Font = .system(size: 11, weight: .medium)
        /// 10pt monospaced — branch names in sidebar, doc tabs
        static let captionMono: Font = .system(size: 10, design: .monospaced)
        /// 9pt — keyboard shortcut badges
        static let micro: Font = .system(size: 9)
        /// 10pt bold monospaced — status badges (A/M/D/R)
        static let badge: Font = .system(size: 10, weight: .bold, design: .monospaced)
    }

    // MARK: - Animation

    enum Animation {
        /// Standard interactive timing — hover, toggle, expand
        static let interactive: SwiftUI.Animation = .easeInOut(duration: 0.15)
        /// Panel show/hide transitions
        static let panel: SwiftUI.Animation = .easeInOut(duration: 0.2)
    }

    // MARK: - Colors

    enum Colors {
        /// Hover background
        static let hoverBg = Color.primary.opacity(Opacity.hover)
        /// Selection background
        static let selectionBg = Color.accentColor.opacity(Opacity.selection)

        // Git status
        static let statusAdded = Color.green
        static let statusModified = Color.orange
        static let statusDeleted = Color.red
        static let statusRenamed = Color.blue
        static let statusMerged = Color.purple

        // Editor git file colors
        static let gitModified = Color(red: 0.886, green: 0.753, blue: 0.553) // #E2C08D
        static let gitUntracked = Color(red: 0.451, green: 0.788, blue: 0.569) // #73C991

        /// Update banner
        static let updateBanner = Color(nsColor: NSColor(red: 0.55, green: 0.15, blue: 0.2, alpha: 1.0))
    }
}
