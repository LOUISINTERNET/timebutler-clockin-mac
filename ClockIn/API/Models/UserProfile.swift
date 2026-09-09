enum UserRole: String, Codable, Sendable, Equatable {
    case user = "USER"
    case manager = "MANAGER"
    case admin = "ADMIN"
}

/// `UserProfileResponse`. The `country` object of the API is not decoded because
/// the app has no use for it.
struct UserProfile: Codable, Sendable, Equatable {
    let id: String
    let name: String
    let email: String
    let role: UserRole
    let department: String?
    let branchOffice: String?
    let avatar: String?
    let isBusinessTripEnabled: Bool?
    let isTimeTrackingEnabled: Bool
}
