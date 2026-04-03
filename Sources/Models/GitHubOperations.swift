// ABOUTME: GitHub operations using the gh CLI.
// ABOUTME: Fetches repo info, PRs, and branch-specific PR status.

import Foundation

struct GitHubRepoInfo {
    let name: String
    let url: String
    let description: String?
    let stars: Int
    let forks: Int
    let openIssues: Int
}

struct GitHubPR {
    let number: Int
    let title: String
    let state: String
    let branch: String
    let url: String
}

enum GitHubOperations {
    private static var gitPath: String? {
        CommandLineTools.path(for: "git")
    }

    /// Check if the project has a GitHub remote.
    static func hasGitHubRemote(at path: String) -> Bool {
        guard let gitPath,
              let remote = run(gitPath, args: ["remote", "get-url", "origin"], in: path) else { return false }
        return remote.contains("github.com")
    }

    /// Fetch repo info via gh CLI.
    static func repoInfo(ghPath: String, at path: String) -> GitHubRepoInfo? {
        guard let json = run(ghPath, args: ["repo", "view", "--json", "name,url,description,stargazerCount,forkCount,openIssueCount"], in: path) else { return nil }
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        return GitHubRepoInfo(
            name: dict["name"] as? String ?? "",
            url: dict["url"] as? String ?? "",
            description: dict["description"] as? String,
            stars: dict["stargazerCount"] as? Int ?? 0,
            forks: dict["forkCount"] as? Int ?? 0,
            openIssues: dict["openIssueCount"] as? Int ?? 0
        )
    }

    /// Fetch open PRs for this repo.
    static func openPRs(ghPath: String, at path: String, limit: Int = 5) -> [GitHubPR] {
        guard let json = run(ghPath, args: ["pr", "list", "--json", "number,title,state,headRefName,url", "--limit", "\(limit)"], in: path) else { return [] }
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        return array.compactMap { dict in
            guard let number = dict["number"] as? Int,
                  let title = dict["title"] as? String,
                  let state = dict["state"] as? String,
                  let branch = dict["headRefName"] as? String,
                  let url = dict["url"] as? String else { return nil }
            return GitHubPR(number: number, title: title, state: state, branch: branch, url: url)
        }
    }

    /// Find an open PR for a specific branch.
    static func prForBranch(ghPath: String, at path: String, branch: String) -> GitHubPR? {
        guard let json = run(ghPath, args: ["pr", "list", "--head", branch, "--json", "number,title,state,headRefName,url", "--limit", "1"], in: path) else { return nil }
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let dict = array.first else { return nil }

        guard let number = dict["number"] as? Int,
              let title = dict["title"] as? String,
              let state = dict["state"] as? String,
              let branch = dict["headRefName"] as? String,
              let url = dict["url"] as? String else { return nil }
        return GitHubPR(number: number, title: title, state: state, branch: branch, url: url)
    }

    /// Find a merged PR for a specific branch.
    static func mergedPRForBranch(ghPath: String, at path: String, branch: String) -> GitHubPR? {
        guard let json = run(ghPath, args: ["pr", "list", "--head", branch, "--state", "merged", "--json", "number,title,state,headRefName,url", "--limit", "1"], in: path) else { return nil }
        guard let data = json.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let dict = array.first else { return nil }

        guard let number = dict["number"] as? Int,
              let title = dict["title"] as? String,
              let state = dict["state"] as? String,
              let branch = dict["headRefName"] as? String,
              let url = dict["url"] as? String else { return nil }
        return GitHubPR(number: number, title: title, state: state, branch: branch, url: url)
    }

    private static func run(_ command: String, args: [String], in directory: String) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: directory)
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
