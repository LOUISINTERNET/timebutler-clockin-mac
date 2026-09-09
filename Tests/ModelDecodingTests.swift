import Foundation
import Testing

struct ModelDecodingTests {
    @Test(arguments: ["status-idle", "status-running", "status-paused", "status-waiting"])
    func statusFixturesDecode(name: String) throws {
        let status = try Fixture.decode(TimeClockStatus.self, from: name)
        #expect(status.workTimeElapsedSeconds >= 0)
    }

    @Test func runningStatusCarriesTimestampsAndCapabilities() throws {
        let status = try Fixture.decode(TimeClockStatus.self, from: "status-running")
        #expect(status.status == .running)
        #expect(status.startTimestamp == 1_753_700_400_000)
        #expect(status.pauseTimestamp == nil)
        #expect(status.canPause)
        #expect(status.canStop)
        #expect(!status.canStart)
        #expect(!status.canResume)
    }

    @Test func waitingStatusCanOnlyStop() throws {
        let status = try Fixture.decode(TimeClockStatus.self, from: "status-waiting")
        #expect(status.status.isActive)
        #expect(status.canStop)
        #expect(!status.canPause)
        #expect(!status.canResume)
        #expect(status.waitSeconds == 120)
    }

    @Test func unknownStateFailsDecoding() {
        let data = Data(#"{"status":"sleeping","workTimeElapsedSeconds":0,"breakElapsedSeconds":0,"accumulatedBreakSeconds":0,"isBusinessTripActive":false,"startOnlyOnTerminal":false,"pauseOnlyOnTerminal":false,"stopOnlyOnTerminal":false}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TimeClockStatus.self, from: data)
        }
    }

    @Test func missingRequiredFieldFailsDecoding() {
        let data = Data(#"{"status":"idle","breakElapsedSeconds":0,"accumulatedBreakSeconds":0,"isBusinessTripActive":false,"startOnlyOnTerminal":false,"pauseOnlyOnTerminal":false,"stopOnlyOnTerminal":false}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TimeClockStatus.self, from: data)
        }
    }

    @Test func terminalOnlyFlagsRemoveActions() throws {
        let idleLocked = TimeClockStatus(status: .idle, startTimestamp: nil, pauseTimestamp: nil, workTimeElapsedSeconds: 0, breakElapsedSeconds: 0, accumulatedBreakSeconds: 0, waitSeconds: nil, isBusinessTripActive: false, startOnlyOnTerminal: true, pauseOnlyOnTerminal: false, stopOnlyOnTerminal: false)
        #expect(idleLocked.allActionsTerminalOnly)

        let runningPauseLocked = TimeClockStatus(status: .running, startTimestamp: 1, pauseTimestamp: nil, workTimeElapsedSeconds: 60, breakElapsedSeconds: 0, accumulatedBreakSeconds: 0, waitSeconds: nil, isBusinessTripActive: false, startOnlyOnTerminal: false, pauseOnlyOnTerminal: true, stopOnlyOnTerminal: false)
        #expect(!runningPauseLocked.canPause)
        #expect(runningPauseLocked.canStop)
        #expect(!runningPauseLocked.allActionsTerminalOnly)

        let runningFullyLocked = TimeClockStatus(status: .running, startTimestamp: 1, pauseTimestamp: nil, workTimeElapsedSeconds: 60, breakElapsedSeconds: 0, accumulatedBreakSeconds: 0, waitSeconds: nil, isBusinessTripActive: false, startOnlyOnTerminal: false, pauseOnlyOnTerminal: true, stopOnlyOnTerminal: true)
        #expect(runningFullyLocked.allActionsTerminalOnly)
    }

    @Test func workSummaryDecodes() throws {
        let summary = try Fixture.decode(WorkSummary.self, from: "work-summary")
        #expect(summary == WorkSummary(commitmentMinutes: 480, workedMinutes: 192, remainingMinutes: 288, percentDone: 40, breakMinutes: 30))
    }

    @Test func profileDecodesAndIgnoresCountry() throws {
        let profile = try Fixture.decode(UserProfile.self, from: "profile")
        #expect(profile.name == "Maria Müller")
        #expect(profile.role == .manager)
        #expect(profile.department == "Engineering")
        #expect(profile.isTimeTrackingEnabled)
    }

    @Test func savedStopResponseDecodesEntry() throws {
        let response = try Fixture.decode(TimeClockStopResponse.self, from: "stop-saved")
        #expect(response == .saved(SavedTimeEntry(id: "98765", workedMinutes: 450, breakMinutes: 30, breakRegulationApplied: true, breakRegulationIgnored: false)))
    }

    @Test func confirmationStopResponseDecodesRegulation() throws {
        let response = try Fixture.decode(TimeClockStopResponse.self, from: "stop-confirmation")
        guard case .confirmationRequired(let regulation) = response else {
            Issue.record("expected confirmationRequired, got \(response)")
            return
        }
        #expect(!regulation.obligatory)
        #expect(!regulation.hasNoRemedy)
        #expect(regulation.correctionWorkMinutes == 30)
        #expect(regulation.resultingWorkMinutes == 420)
        #expect(regulation.detailText.hasPrefix("Die Pausenregelung"))
    }

    @Test func confirmationWithoutFlagsFailsDecoding() {
        let data = Data(#"{"outcome":"confirmationRequired","breakRegulation":{"detailText":"x"}}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(TimeClockStopResponse.self, from: data)
        }
    }

    @Test func confirmationWithoutRemedyOmitsCorrectionValues() throws {
        let data = Data(#"{"outcome":"confirmationRequired","breakRegulation":{"hasNoRemedy":true,"obligatory":true,"detailText":"Maximale Arbeitszeit überschritten."}}"#.utf8)
        let response = try JSONDecoder().decode(TimeClockStopResponse.self, from: data)
        guard case .confirmationRequired(let regulation) = response else {
            Issue.record("expected confirmationRequired, got \(response)")
            return
        }
        #expect(regulation.hasNoRemedy)
        #expect(regulation.resultingWorkMinutes == nil)
    }

    @Test func oauthResponsesDecode() throws {
        let token = try Fixture.decode(OAuthTokenResponse.self, from: "oauth-token")
        #expect(token.refreshToken == "rt-a1b2c3d4e5f6")
        #expect(token.expiresIn == 3600)

        let challenge = try Fixture.decode(MfaChallengeResponse.self, from: "oauth-mfa")
        #expect(challenge.mfaRequired)
        #expect(challenge.mfaExpiresIn == 300)

        let error = try Fixture.decode(OAuthErrorResponse.self, from: "oauth-error")
        #expect(error.error == "invalid_grant")
    }

    @Test func stopRequestOmitsAbsentDecision() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let plain = try encoder.encode(TimeClockStopRequest.standard())
        #expect(String(decoding: plain, as: UTF8.self) == #"{"categoryId":0,"projectId":0}"#)
        let applied = try encoder.encode(TimeClockStopRequest.standard(decision: .apply))
        #expect(String(decoding: applied, as: UTF8.self) == #"{"breakRegulation":"apply","categoryId":0,"projectId":0}"#)
    }
}
