// ABOUTME: System prompts injected into claude sessions based on settings.
// ABOUTME: Written to ~/.ff2/prompts/ and referenced via --system-prompt-file.

import Foundation

enum SystemPrompts {
    private static var promptsDir: URL {
        AppConstants.appSupportDirectory.appendingPathComponent("prompts")
    }

    /// Write the auto-rename-branch prompt to disk and return the path.
    static func autoRenameBranchPromptPath() -> String {
        let dir = promptsDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("auto-rename-branch.md")
        let prompt = """
        When the user presents their first request:

        1. Generate a short descriptive git branch name summarizing the task.
        2. Rename the current branch using `git branch -m <new-name>`.
        3. Keep the existing branch prefix (everything before the last `/`).
        4. Use kebab-case and keep the descriptive part under 6 words.
        5. After renaming, continue with the task normally.

        If the branch already has a meaningful descriptive name (not a random generated name), do nothing.

        Example: if the branch is `ff2/scan-deep-thr` and the user asks to "fix the login timeout bug",
        rename it to `ff2/fix-login-timeout-bug`.
        """
        try? prompt.write(toFile: path.path, atomically: true, encoding: .utf8)
        return path.path
    }
}
