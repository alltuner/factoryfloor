# Factory Floor Mobile App — Design Notes

> **Living document.** This design depends on [Corner Office](remote-coordinator-design.md)
> being finalized first. The mobile app is a client of the Corner Office API, so its shape
> is determined by that protocol.

## Concept

A lightweight mobile client for Corner Office. Does not run agents, manage terminals, or
do git operations. It dispatches jobs, shows status, and gets out of the way.

The killer UX: you're on your phone, you think of something, you type "fix the flaky test
in auth_test.go," pick your home Mac as the target, and by the time you sit down it's done.

## What the app does

- Show connected Factory Floor instances and their status (online/offline/busy)
- Dispatch a new job (pick a repo, type a prompt, pick a target instance)
- Push notifications when a job completes or fails
- View job history and results (branch name, PR link, summary)
- Re-run or cancel a job

## What the app does NOT do

- Terminal views. Nobody wants a terminal on a phone.
- Git diffs. Link to GitHub instead.
- Anything involving Ghostty or terminal infrastructure.
- Run agents locally.

## Architecture

Same API the Corner Office web UI uses. The mobile app is just another client.

```
[Mobile App] ---> [Corner Office API] <--poll-- [Factory Floor instances]
```

## Additions needed in Corner Office

These features need to exist in Corner Office before the mobile app makes sense:

- **Push notifications**: Corner Office pushes to APNs (iOS) / FCM (Android) when a job
  completes or fails. Self-hosted could integrate with ntfy.sh or similar.
- **Job results/summary**: Factory Floor needs to report something useful on completion.
  At minimum: branch name, one-line summary. Ideally: PR URL if one was created.
- **Auth token for mobile**: the pairing code flow from the hosted onboarding works here
  too. Scan a QR code from the web UI or enter a code manually, phone is paired.

## Business angle

- Mobile app is a natural pro/team tier feature for the hosted Corner Office.
- Self-hosted users can use the Corner Office web UI on their phone browser.
- On-call scenario: get an alert, dispatch a fix from your phone, review the PR later.

## Platform

TBD. Options:
- Native Swift (iOS only first, reuse some Factory Floor domain knowledge)
- React Native / Flutter (both platforms, but new stack)
- PWA (no app store, works everywhere, but no push notifications on iOS... wait, iOS
  supports web push now. Could be enough for v1.)

## Open questions

- Is iOS-only acceptable for v1? Factory Floor is Mac-only, so the user base skews Apple.
- PWA vs native: PWA avoids the app store and works immediately, but feels less polished.
  Could ship PWA first and go native if there's demand.
- How much job context does the mobile app need? Just the prompt and result, or also
  intermediate status (agent is thinking, agent made 3 commits, etc.)?
- Does the mobile app need to show the web UI's full dashboard, or is it a simpler
  "dispatch and notify" tool?
