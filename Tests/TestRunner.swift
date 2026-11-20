import Testing

/// Entry point for the test binary built by `make test` (no SwiftPM needed).
@main
struct TestRunner {
    static func main() async {
        await Testing.__swiftPMEntryPoint() as Never
    }
}
