# Announcing mouse-in-the-corner

Copy for the places Omarchy plugins get discovered. Post from the maintainer
account, with `docs/demo.gif` — it captions each step (grip, pad, `Wider`,
`Narrower`) so it works without a voiceover — or `docs/pad.png` as a still.

## One-liner

> A mousetrap in the corner of the focused window: click it to resize the window
> or move it around the layout — and it shows the hotkey that does the same.

## Short post (Reddit / Mastodon / forum)

**mouse-in-the-corner — resize or move a window from its own corner**

Hyprland has no per-window buttons, so this is a small Quickshell overlay: a
mousetrap appears in the top-left corner of the focused window, and clicking it
drops a pad with `↑ ↓ ← →` and `−` / `+`.

- Tiled window: the arrows swap the tile with its neighbour, `−`/`+` moves the
  split edge. Directions with no neighbour are not shown at all.
- Floating window: the arrows nudge it, `−`/`+` resizes it.
- Every row shows the hotkey that does the same thing (`SUPER SHIFT + ←`,
  `SUPER + −`), read from your own Omarchy bindings — so the pad teaches the
  keyboard route.
- The grip is 34 px and resizable: `omarchy-shell window-controls size 44`.
  It remembers the size across restarts.
- Optional: bind the pad to a key with
  `omarchy-shell window-controls toggle`.

The GIF is a real terminal, unedited: the grip sits in its corner, the pad opens
under it, then `Wider` and `Narrower` are clicked in turn and the window edge
follows.

Install (Omarchy Quattro, no extra packages):

```bash
omarchy plugin add https://github.com/evtriest/mouse-in-the-corner.git
# Review the plugin, then enable it:
omarchy plugin enable eep.window-controls
```

Remove it with `omarchy plugin remove eep.window-controls`.

MIT, one QML file, ~0.1 % of a core. Issues and PRs welcome — especially from
anyone on a multi-monitor or non-2x setup.

## Marketplace submission

The listing goes through the community registry:
<https://plugins.omarchy.org/publish.html> → issue on
`omacom/omarchy-plugin-marketplace`.

- Repository: <https://github.com/evtriest/mouse-in-the-corner>
- Category: `Desktop`
- Tags: `Hyprland`, `Quickshell`, `System` (the form takes at most three)
- Preview: `preview.png` in the repository root

## Checklist before posting

- [ ] `git push` is up to date and `main` is the default branch
- [ ] README install + uninstall verified on a clean shell
- [ ] `docs/demo.gif` is attached and plays in the timeline (people click those)
- [ ] reply to questions in the thread — the first day decides how far it travels
