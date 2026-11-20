import Testing

struct AppLayoutTests {
    @Test func defaultLayoutIsSidebar() {
        #expect(AppLayout.defaultLayout == .sidebar)
    }

    @Test(arguments: [nil, "", "bogus"] as [String?])
    func unknownOrMissingStoredValueFallsBackToSidebar(stored: String?) {
        #expect(AppLayout(stored: stored) == .sidebar)
    }

    @Test(arguments: AppLayout.allCases)
    func rawValueRoundTrips(layout: AppLayout) {
        #expect(AppLayout(stored: layout.rawValue) == layout)
        #expect(AppLayout(rawValue: layout.rawValue) == layout)
    }

    @Test(arguments: AppLayout.allCases)
    func everyLayoutHasLabelAndSummary(layout: AppLayout) {
        #expect(!layout.label.trimmingCharacters(in: .whitespaces).isEmpty)
        #expect(!layout.summary.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    @Test func labelsAreUnique() {
        let labels = AppLayout.allCases.map(\.label)
        #expect(Set(labels).count == labels.count)
    }

    @Test func casesAreInMenuOrder() {
        #expect(AppLayout.allCases == [.sidebar, .nowDownloading, .classic])
    }
}

struct JobFilterTests {
    private func matchingFilters(state: JobState, failedCount: Int) -> [JobFilter] {
        JobFilter.allCases.filter { $0.matches(state: state, failedCount: failedCount) }
    }

    @Test(arguments: [JobState.waiting, .fetching, .downloading])
    func activeStatesAreInTheQueueOnly(state: JobState) {
        #expect(matchingFilters(state: state, failedCount: 0) == [.queue])
    }

    @Test func doneWithoutFailuresIsFinished() {
        #expect(matchingFilters(state: .done, failedCount: 0) == [.finished])
    }

    @Test func doneWithFailuresNeedsAttention() {
        #expect(matchingFilters(state: .done, failedCount: 2) == [.attention])
    }

    @Test func failedNeedsAttention() {
        #expect(matchingFilters(state: .failed("x"), failedCount: 0) == [.attention])
    }

    @Test func cancelledIsFinished() {
        #expect(matchingFilters(state: .cancelled, failedCount: 0) == [.finished])
    }

    @Test(arguments: [0, 2])
    func everyStateMatchesExactlyOneFilter(failedCount: Int) {
        let states: [JobState] = [.waiting, .fetching, .downloading, .done, .failed("x"), .cancelled]
        for state in states {
            #expect(matchingFilters(state: state, failedCount: failedCount).count == 1)
        }
    }
}
