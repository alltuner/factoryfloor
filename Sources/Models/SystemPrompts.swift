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

    static let reviewGuidePrompt = """
    After every code change, you MUST open `.factoryfloor-state/review.json` and evaluate whether \
    it needs updates. You may conclude it doesn't — but you cannot skip the evaluation, even for \
    trivial changes. This file externalizes your thought process — reasoning, trade-offs, \
    and decisions — so a reviewer sees why the code looks the way it does, not just what changed. \
    Prefer incremental updates across prompts; rewrite freely if scope or structure has shifted. \
    Write as valid JSON using: \
    Annotate: trade-offs, uncertainty, non-obvious behavior, cross-file connections, etc. \
    Don't annotate: what the code already says clearly or context that belongs in a code comment \
    (needed by future readers of the code, not by the reviewer of this diff). \
    cat > .factoryfloor-state/review.json << 'REVIEW_EOF'\n{\n  ...\n}\nREVIEW_EOF \
    Format: \
    { \
      "review_guide": { \
        "title": "Imperative summary, like a commit message", \
        "summary": "2-4 sentences: what, why, and essential context." \
      }, \
      "order": [ \
        { "file": "src/auth/token.ts", "reason": "Core rotation logic and new TokenFamily concept" }, \
        { "file": "tests/auth/token.test.ts", "reason": "Edge case tests clarify intended behavior" } \
      ], \
      "annotations": [ \
        { "file": "src/auth/token.ts", "line": 34, "body": "Separate table for token families instead of new columns. Tradeoff: extra join vs cleaner schema." }, \
        { "file": "src/auth/token.ts", "lines": [78, 95], "body": "Range annotation for a block of related logic." } \
      ] \
    } \
    order: Controls reading order in the review — lead with the core concept, not alphabetical. \
    annotations: inline comments for the reviewer at specific lines. "line" for single, \
    "lines": [start, end] for ranges. Keep bodies concise. Only annotate changed lines.
    """

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
