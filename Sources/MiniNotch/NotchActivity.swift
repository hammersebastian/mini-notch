import Foundation

/// Gemeinsame Prioritätsstufen für Activities, die sich dieselbe Notch teilen.
enum ActivityPriority {
    static let persistentContent = 30
    static let systemHUD = 80
}

/// Gemeinsame, UI-unabhängige Grundlage für Inhalte, die zeitweise in der
/// Notch angezeigt werden können.
///
/// Darstellung bleibt bewusst außerhalb dieses Vertrags und wird von der UI
/// für den jeweils ausgewählten Activity-Snapshot geliefert.
protocol NotchActivity {
    /// Über Aktualisierungen hinweg stabile Kennung der Activity.
    var id: String { get }

    /// Höhere Werte verdrängen gleichzeitig aktive Activities mit niedrigerer
    /// Priorität.
    var priority: Int { get }

    /// Optionale Lebensdauer ab der letzten Veröffentlichung. `nil` steht für
    /// eine permanente Activity; Werte kleiner oder gleich null führen zur
    /// unmittelbaren Entfernung.
    var autoDismissAfter: TimeInterval? { get }

    /// Gibt an, ob die Activity aktuell für eine Anzeige infrage kommt.
    var isActive: Bool { get }
}
