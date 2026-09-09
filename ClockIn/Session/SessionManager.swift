import Foundation

/// Owns the stored credentials and is the only place that refreshes OAuth tokens.
///
/// Refresh tokens are single-use, so concurrent callers must share one refresh. The
/// in-flight refresh is kept as a `Task`; every caller awaits that task instead of starting
/// another one. Actor reentrancy makes the join point cheap and needs no extra lock.
/// Sign-in and sign-out cancel that task, so a refresh that finishes after either can
/// neither write stale credentials to the keychain nor expire the new session.
actor SessionManager: TokenProvider {
    static let refreshLeadTime: TimeInterval = 60

    private let credentialStore: any CredentialStore
    private let oauthClient: OAuthClient
    private let now: @Sendable () -> Date
    private let logger = Log.logger(.session)
    private let broadcaster = SessionStateBroadcaster()
    private var credentials: Credentials?
    private var expired = false
    private var refreshTask: Task<OAuthSession, Error>?

    init(credentialStore: any CredentialStore, oauthClient: OAuthClient, now: @escaping @Sendable () -> Date = Date.init) throws {
        self.credentialStore = credentialStore
        self.oauthClient = oauthClient
        self.now = now
        credentials = try credentialStore.load()
    }

    deinit {
        broadcaster.finish()
    }

    /// State changes for one subscriber, newest buffered. The stream ends when the
    /// subscriber's task is cancelled; a later call subscribes afresh.
    func states() -> AsyncStream<SessionState> {
        broadcaster.subscribe()
    }

    func currentState() -> SessionState {
        guard let credentials else {
            return .notConfigured
        }
        return expired ? .expired : .active(credentials.kind)
    }

    // MARK: TokenProvider

    func accessToken() async throws -> String {
        guard let credentials else {
            throw SessionError.notConfigured
        }
        if expired {
            throw SessionError.expired
        }
        switch credentials {
        case .apiToken(let token):
            return token
        case .oauth(let session):
            if session.expiresAt.timeIntervalSince(now()) > Self.refreshLeadTime {
                return session.accessToken
            }
            return try await refreshedSession(from: session).accessToken
        }
    }

    func recoverFromUnauthorized() async throws -> String? {
        guard let credentials else {
            throw SessionError.notConfigured
        }
        switch credentials {
        case .apiToken:
            return nil
        case .oauth(let session):
            return try await refreshedSession(from: session).accessToken
        }
    }

    /// Timebutler rejected the credentials for good (401 that a refresh could not fix).
    func markExpired() {
        guard !expired else {
            return
        }
        expired = true
        logger.notice("Session marked as expired")
        publishState()
    }

    // MARK: Sign-in and sign-out

    /// Verifies the token against the API before it replaces the stored credentials (FR-S2).
    func signIn(apiToken: String, verify: @Sendable (String) async throws -> UserProfile) async throws -> UserProfile {
        let token = apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = try await verify(token)
        try adopt(.apiToken(token))
        return profile
    }

    func signIn(email: String, password: String) async throws -> LoginResult {
        let result = try await oauthClient.signIn(email: email, password: password)
        if case .signedIn(let session) = result {
            try adopt(.oauth(session))
        }
        return result
    }

    func completeMFA(mfaToken: String, code: String, email: String) async throws -> OAuthSession {
        let session = try await oauthClient.completeMFA(mfaToken: mfaToken, code: code, email: email)
        try adopt(.oauth(session))
        return session
    }

    func signOut() throws {
        try credentialStore.delete()
        cancelRefresh()
        credentials = nil
        expired = false
        logger.notice("Signed out")
        publishState()
    }

    // MARK: Internals

    private func adopt(_ newCredentials: Credentials) throws {
        try credentialStore.save(newCredentials)
        cancelRefresh()
        credentials = newCredentials
        expired = false
        switch newCredentials {
        case .apiToken:
            logger.notice("Signed in with a personal API token")
        case .oauth:
            logger.notice("Signed in with an OAuth session")
        }
        publishState()
    }

    private func refreshedSession(from session: OAuthSession) async throws -> OAuthSession {
        let task = refreshTask ?? startRefresh(from: session)
        defer {
            if refreshTask == task {
                refreshTask = nil
            }
        }
        do {
            return try await task.value
        } catch let error as SessionError where error.isRejectedGrant {
            if task.isCancelled {
                throw CancellationError()
            }
            if refreshTask == task {
                logger.error("Refresh token rejected: \(error.userMessage, privacy: .public)")
                markExpired()
            }
            throw SessionError.expired
        }
    }

    private func startRefresh(from session: OAuthSession) -> Task<OAuthSession, Error> {
        let task = Task { [oauthClient] in
            let refreshed = try await oauthClient.refresh(session: session)
            try store(refreshed)
            return refreshed
        }
        refreshTask = task
        return task
    }

    /// Runs inside the refresh task, unless sign-in or sign-out cancelled it while the token
    /// endpoint was answering. The pair is adopted in memory before the keychain write: the
    /// old refresh token is already spent, so a failing write must not throw the new one away.
    /// The write error still reaches the caller; the next launch then needs a fresh sign-in.
    private func store(_ refreshed: OAuthSession) throws {
        try Task.checkCancellation()
        credentials = .oauth(refreshed)
        try credentialStore.save(.oauth(refreshed))
    }

    private func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func publishState() {
        broadcaster.publish(currentState())
    }
}
