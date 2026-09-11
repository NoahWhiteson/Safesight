import Foundation
import UIKit

struct CLIArgs {
    var photo: String = ""
    var resultJSON: String = ""
    var out: String = ""
    var logo: String = ""
}

func parseArgs() -> CLIArgs {
    var args = CLIArgs()
    var i = 1
    let argv = CommandLine.arguments
    while i < argv.count {
        let key = argv[i]
        let val = i + 1 < argv.count ? argv[i + 1] : ""
        switch key {
        case "--photo": args.photo = val; i += 2
        case "--result": args.resultJSON = val; i += 2
        case "--out": args.out = val; i += 2
        case "--logo": args.logo = val; i += 2
        default:
            fputs("Unknown arg: \(key)\n", stderr)
            exit(2)
        }
    }
    return args
}

@main
enum ShareExportCLI {
    static func main() {
        let args = parseArgs()
        guard !args.photo.isEmpty, !args.resultJSON.isEmpty, !args.out.isEmpty else {
            fputs("Usage: share-export --photo PATH --result PATH.json --out PATH.png [--logo PATH]\n", stderr)
            exit(2)
        }

        if !args.logo.isEmpty, let logo = UIImage(contentsOfFile: args.logo) {
            ScanShareExporter.logoOverride = logo
        }

        guard let image = UIImage(contentsOfFile: args.photo) else {
            fputs("Failed to load photo: \(args.photo)\n", stderr)
            exit(1)
        }

        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: args.resultJSON))
        } catch {
            fputs("Failed to read result JSON: \(error)\n", stderr)
            exit(1)
        }

        let decoded: ScanAnalysisResponse
        do {
            decoded = try JSONDecoder().decode(ScanAnalysisResponse.self, from: data)
        } catch {
            fputs("Failed to decode result JSON: \(error)\n", stderr)
            exit(1)
        }

        guard let png = ScanShareExporter.renderPNG(
            image: image,
            hazards: decoded.hazards,
            score: decoded.score
        ) else {
            fputs("ScanShareExporter returned nil\n", stderr)
            exit(1)
        }

        do {
            try png.write(to: URL(fileURLWithPath: args.out), options: .atomic)
            print("wrote \(args.out) (\(png.count) bytes) score=\(decoded.score) hazards=\(decoded.hazards.count)")
        } catch {
            fputs("Failed to write PNG: \(error)\n", stderr)
            exit(1)
        }
    }
}
