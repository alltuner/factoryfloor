# Adapting Existing Repositories for Factory Floor (Dockyard)

To get the best experience when using Factory Floor (sometimes referred to as Dockyard) with your existing repositories, you need to configure how the IDE sets up, runs, and manages your project's environment.

This guide explains how to properly configure your repository to ensure environment variables are picked up, browsers auto-target your app, and workstreams are provisioned correctly.

## 1. The Configuration File

Factory Floor looks for a configuration file in the root of your repository to understand how to build and run your project. 

Create a `.dockyard.json` file in the root of your project:

```json
{
  "setup": "npm install",
  "run": "npm run dev",
  "teardown": "npm run clean"
}
```

### Configuration Keys:
*   **`setup`**: The command run automatically when a new workstream (branch/worktree) is created. Use this for dependency installation (e.g., `npm install`, `pip install -r requirements.txt`, `cargo fetch`).
*   **`run`**: The command executed when you press `Cmd+Shift+Return` (Start/Rerun). This should start your local development server.
*   **`teardown`** *(Optional)*: The command run before a workstream is archived or destroyed. Useful for cleaning up local build artifacts, stopping detached containers, etc.

*Note: Factory Floor also supports legacy fallback configuration names like `.emdash.json`, `conductor.json`, or `.superset/config.json` for backwards compatibility.*

## 2. Environment Variables (`.env`)

When Dockyard creates a new workstream, it isolates the branch in a dedicated Git worktree (under `~/.dockyard/worktrees/`). 

To ensure your environment variables are correctly picked up without manually copying `.env` files around:

1.  Keep your primary `.env` file in your **base repository directory**.
2.  Factory Floor will automatically **symlink** the `.env` file from the base repository into the root of each new workstream directory (if this feature is enabled in your Factory Floor settings).
3.  Any modifications to the `.env` file within a workstream will automatically reflect across all your workstreams and the base repository.

## 3. Automatic Port Detection

When you start your project using the `run` command (e.g., `npm run dev`), Factory Floor wraps the process using its `ff-run` launcher. 

You **do not** need to manually configure localhost URLs for the built-in browser. The `ff-run` launcher automatically:
1.  Monitors the child process tree of your `run` command.
2.  Detects any listening TCP ports opened by your application.
3.  Automatically retargets the built-in IDE browser to the detected localhost port (e.g., `http://localhost:3000`).

## 4. Git Worktrees and Branching

Because Factory Floor uses Git worktrees to parallelize work:
*   **Commit/Stash Changes**: Make sure your base repository is relatively clean. Uncommitted changes in the base repo won't be copied to the isolated workstreams.
*   **Avoid `.git` Hardcoding**: Avoid scripts that assume `.git` is a directory. In worktrees, `.git` is a file pointing back to the main repository. Most modern tools handle this fine, but custom bash scripts using `[ -d .git ]` might break. Use `git rev-parse --git-dir` instead.

## 5. Adding to `.gitignore`

It's highly recommended to commit `.dockyard.json` to your repository so your entire team benefits from zero-config onboarding.

You generally **do not** need to add Dockyard worktree directories to your `.gitignore`, because Dockyard provisions worktrees entirely outside of your project path (specifically in `~/.dockyard/worktrees/`).

---

By adding a simple `.dockyard.json` to your repository root, Dockyard will seamlessly manage your environment, automate installations, and connect your embedded browser automatically!
