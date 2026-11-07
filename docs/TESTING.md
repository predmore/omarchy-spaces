# Runtime validation

Headless tests do not certify compositor integration. Initial release validation was performed on the tested versions listed in the README.

Check these on the installed plugin:

1. Open on the focused display; inspect all desktop slots, previews, theme colors, icons, and notch clearance.
2. Hover an occupied desktop and an empty one. The windows below should change; the actual workspace should stay unchanged.
3. Move into the window row. The previewed desktop should remain selected.
4. Swipe horizontally and hold halfway; motion should follow the finger. Release, cancel, and swipe beyond either edge.
5. Use keyboard navigation in both tiers. Verify window selection and scroll offsets survive browsing away and back.
6. Click a window, an empty desktop, and both overflow arrows. Arrow clicks must not activate the window underneath.
7. Close and confirm captures are released and the configured normal horizontal gesture is restored.
8. With capture priorities changing above the configured live limit, outgoing frames must remain visible during swiping and settling. After settling, retained captures should be released; after closing, all should be gone.
9. Disable or omit the optional Lua helper. Opening, hovering, mouse/keyboard navigation, and closing should work without Lua errors or overriding horizontal gestures.

Diagnostic state, including capture counts, current versus previewed workspace, safe inset, and thumbnail geometry:

```bash
omarchy-shell shell call predmore.spaces diagnostics ''
```

The diagnostic method is read-only and returns window counts, opaque compositor addresses for visible windows, and geometry; it does not return captured pixels or window titles. Keep reports scoped to what is needed and use staged application content when sharing screenshots.

## Initial local checks

The development build exercised real Wayland pointer clicks and keyboard input, compositor custom swipe events, hover/commit separation, preview cleanup, and a 32-entry capture stress fixture sharing an actual application capture source. That fixture validates budget and retention behavior; it does not stand for 32 independently launched applications. Direct physical trackpad feel and additional hardware remain manual/community checks.
