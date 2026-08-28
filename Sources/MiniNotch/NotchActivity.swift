/// Gemeinsame, UI-unabhängige Grundlage für Inhalte, die zeitweise in der
/// Notch angezeigt werden können.
///
/// Priorisierung, automatische Beendigung und Darstellung gehören bewusst
/// noch nicht zu diesem Vertrag. Diese Zuständigkeiten werden erst mit den
/// dafür vorgesehenen Activity-Engine-Schritten eingeführt.
protocol NotchActivity {
    /// Über Aktualisierungen hinweg stabile Kennung der Activity.
    var id: String { get }

    /// Gibt an, ob die Activity aktuell für eine Anzeige infrage kommt.
    var isActive: Bool { get }
}
