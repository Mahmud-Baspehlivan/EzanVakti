import ActivityKit

/// Live Activity'nin kimliği. Durum tipi `PrayerActivityContent`; o tip
/// ActivityKit'ten bağımsız tutulduğu için görünümler Xcode olmadan
/// render edilip denetlenebiliyor.
struct PrayerActivityAttributes: ActivityAttributes {
    typealias ContentState = PrayerActivityContent
}
