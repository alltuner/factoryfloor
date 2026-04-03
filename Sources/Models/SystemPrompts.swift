// ABOUTME: System prompts injected into claude sessions based on settings.
// ABOUTME: Passed inline via --append-system-prompt.

import Foundation

enum SystemPrompts {
    static func restrictToWorktreePrompt(worktreePath: String) -> String {
        """
        CRITICAL FILESYSTEM CONSTRAINT: You MUST NOT create, edit, delete, or modify any files \
        outside of the following directory: \(worktreePath)
        This includes temporary files, configuration files, and any other filesystem writes. \
        All file operations MUST target paths within \(worktreePath). \
        If a task requires modifying files outside this path, explain what needs to change and \
        ask the user to do it manually or to enable unrestricted filesystem access in Settings.
        """
    }

    static let autoRenameBranchPrompt = """
    You are working inside Factory Floor, a Mac app that runs coding agents in parallel worktrees. \
    When the user presents their first request: \
    1) Generate a short descriptive git branch name summarizing the task. \
    Use concrete, specific language. Avoid abstract nouns. \
    2) Rename the current branch using `git branch -m <new-name>`. \
    3) Keep the existing branch prefix (everything before the last `/`). \
    4) Use kebab-case and keep the descriptive part under 6 words. \
    5) Write a one-sentence task description: \
    `mkdir -p .factoryfloor-state && echo "your description" > .factoryfloor-state/description` \
    6) After renaming and writing the description, continue with the task normally. \
    If the branch already has a meaningful descriptive name (not a random generated name), \
    skip the rename but still write the description if `.factoryfloor-state/description` does not exist. \
    Example: if the branch is `ff/scan-deep-thr` and the user asks to "fix the login timeout bug", \
    rename it to `ff/fix-login-timeout-bug` and write "Fix login timeout by increasing session TTL" to the description file.
    """
}
