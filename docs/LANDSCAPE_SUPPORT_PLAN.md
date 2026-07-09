# Kayoko Compact Landscape Support Plan

Status: initial implementation complete; root `gmake` and RootHide package build passed
Owner context: original request is "add landscape support to Kayoko"

## Implementation Status

- Implemented a `KayokoPanelPresentationMode` contract for portrait drawer vs compact-landscape fullscreen.
- Implemented compact-landscape hosting with a Kayoko-owned overlay `UIWindow` attached to the captured status-bar `UIWindowScene`.
- The overlay window is clipped to bounds, not actively made key during show, passes touches through while the Kayoko root view is hidden, and has its frame reset from `UIScreen.mainScreen.bounds` after becoming visible.
- Compact landscape ignores `HeightInPoints`, sets the panel to fullscreen, and relies on overlay/root safe-area insets.
- Search begin/end no longer drives panel frame changes in compact landscape and does not reset the base fullscreen safe-area mode.
- Rotation hiding has an explicit `UIWindowWillRotateNotification` observer and uses the existing hide pipeline with fade animation style.
- Root `gmake` passed after implementation.
- RootHide package build passed and produced `packages/com.82flex.kayoko_4.2_iphoneos-arm64e.deb`.
- On-device functional validation is still required for compact-landscape show/dismiss/search/preview/word-selection/direct-paste behavior.

## Confirmed Scope

- Support iPhone compact landscape only.
- Do not include iPad, Stage Manager, floating keyboard, or non-phone layout work in the first pass.
- In compact landscape, Kayoko uses a fullscreen presentation.
- In compact landscape, there is no half-height drawer state.
- In compact landscape, search remains available, but search must not be modeled as a half-to-fullscreen panel transition.
- If Kayoko is visible while the device rotates, hide Kayoko instead of relaying out the visible panel.
- Existing portrait behavior should remain unchanged unless a shared fix is required for correctness.

## Pre-Implementation Facts

- Before this implementation, `KayokoCoreRuntime -show` rejected landscape by checking `frontmostAppIsLandscape`.
- `frontmostAppIsLandscape` reads the private `UIApplication _frontMostAppOrientation` value; the implementation now uses that as the presentation-mode signal instead of a hard rejection.
- Before this implementation, the installed panel frame was always computed as a bottom-aligned drawer using `HeightInPoints`.
- `KayokoPanelPresentationController` treats downward vertical pan as the dismissal direction.
- Before this implementation, `KayokoSearchPresentationController` treated search activation as a fullscreen expansion and search cancellation as a frame restoration.
- `KayokoSwipeUpGestureRecognizer` recognizes an upward movement along the y axis.
- Existing safe-area fixes rely on scene-scoped window inspection because the Kayoko panel can live inside `UIStatusBarWindow`, whose local safe-area bottom can be zero.
- Core currently consumes `CoreHide` Darwin notifications by calling the normal `KayokoCoreRuntime -hide` path.
- Helper currently forwards keyboard/window lifecycle changes to `CoreHide`: `UIKeyboardWillHideNotification`, `UIWindowDidResignKeyNotification`, and keyboard view `didMoveToWindow` hooks can all hide Kayoko.
- SpringBoard currently hides Kayoko from specific visibility hooks such as home screen appearance, cover sheet appearance, Spotlight/library search disappearance, and app switcher/layout transitions. The rotation probe showed that current rotation hiding reaches this layout-transition path rather than an explicit rotation-hide path.

## Known Device/Runtime Facts

- Target probe device: iOS 15.0 on Dopamine RootHide.
- The device is connected and `.venv/bin` Frida tools are available for runtime probes.
- `_frontMostAppOrientation` is a known global orientation source.
- First SpringBoard probe verified that current rotation hiding is triggered by SpringBoard layout-transition hiding, with `UIWindowWillRotateNotification` available earlier as a narrower rotation signal.

## Product Model

Kayoko should have two presentation modes:

- Portrait mode: existing bottom drawer with existing height preference and existing search fullscreen expansion.
- Compact landscape mode: fullscreen modal surface with no collapsed drawer geometry.

In compact landscape, the existing `HeightInPoints` preference is ignored. No landscape-specific size preference is planned for the first pass.

## Proposed Compact Landscape Behavior

- Showing Kayoko in compact landscape should cover the current hosting window bounds.
- Main content should respect top, left, right, and bottom safe areas.
- History, Favorites, clear confirmation, authorization required, storage error, preview, and word selection views should all remain reachable.
- Search filtering, search tokens, app tokens, tag tokens, and keyboard avoidance should remain functional.
- Search begin/end should only change search state, first responder state, token visibility, and list filtering. It should not animate between drawer and fullscreen frames.
- Exiting search should keep Kayoko visible in compact landscape unless the user explicitly dismisses Kayoko.
- The outside-dismiss overlay is irrelevant in fullscreen compact landscape because there is no outside region.

## Resolved Decisions

Decision CL-01: Search bar visibility in compact landscape

- Status: resolved.
- Decision: keep portrait behavior. The search bar is hidden by default and revealed through the same list/header interaction used in portrait.
- Rationale: a permanently visible search bar consumes default visual space in compact landscape.

Decision CL-02: Dismiss affordance in compact landscape

- Status: resolved.
- Decision: keep the existing grabber/handle as the close affordance. Tapping it dismisses Kayoko.

Decision CL-03: Downward pan dismissal in compact landscape

- Status: resolved.
- Decision: keep the same downward pan dismissal logic as portrait.

Decision CL-04: Compact landscape header metrics

- Status: resolved.
- Decision: keep the existing title/header visual metrics. Do not compact the main header or search header for the first pass.
- Rationale: avoid breaking the existing title-row visual style. The search bar remains folded by default, so it does not need a compact landscape metric change.

Decision CL-05: Rotation hide semantics

- Status: resolved.
- Decision: rotation-triggered hiding uses the existing hide flow. Focus restoration is not a rotation-specific behavior; it should follow the same session semantics as any other Kayoko hide.
- Rationale: screen rotation is only the reason Kayoko hides, not a separate focus-management mode.

Decision CL-06: Activation methods in compact landscape

- Status: resolved.
- Decision: keep all currently enabled activation methods available in compact landscape, subject to probe results.

Decision CL-07: Show/hide animation in compact landscape

- Status: resolved.
- Decision: use a fullscreen slide/fade animation. Do not use fade-only.

Decision CL-10: Rotation hide animation

- Status: resolved.
- Decision: use a fade hide when rotation hides Kayoko.
- Rationale: this keeps rotation hiding visually controlled without treating rotation as a distinct product flow.

Decision CL-11: Settings "Show Kayoko" button in compact landscape

- Status: resolved.
- Decision: the Settings "Show Kayoko" action remains allowed in compact landscape and uses the normal show/hide behavior. Do not add focus-restoration behavior just because the show source was Settings.

## Product Constraints

- Do not add compact-landscape-only search buttons or header controls.
- Do not change safe-area visual styling as a product decision. The fullscreen surface should follow the existing Kayoko visual language unless verification finds a concrete rendering bug.
- Do not change direct paste, system gesture suppression, shadow, edge styling, or swipe-up direction as product features for this work.
- Do not treat third-party keyboard ownership, focus restoration, safe-area math, or keyboard inset math as landscape-specific product axes. They inherit existing semantics unless a concrete probe shows the current shared path breaks.
- Reuse the existing fullscreen system-gesture suppression path. In compact landscape, "screen top" is visual, but the suppression policy remains category-based and should not be redefined for orientation.

## Layout Decisions

Decision CL-12: Compact landscape content layout model

- Status: resolved for v1.
- Why this matters: "fullscreen" only defines the panel frame. It does not decide whether the content remains the current single-column navigation model, becomes a centered readable column, or becomes a split master/detail layout.
- Current implementation constraint: `KayokoMainView` owns one `headerView` above one `contentContainerView`, and every content surface is installed to fill that same container. History, Favorites, empty/error/authorization states, preview, and word selection all assume mutually exclusive full-container pages.
- Option A: single-column full-width. Keep the existing header plus one content container, expand it to fullscreen compact landscape, and let lists/search/preview/word selection fill the safe-area content width.
- Option B: single-column centered readable width. Keep the same navigation semantics, but constrain header/content/tag/search surfaces to a maximum width centered inside the fullscreen blur.
- Option C: split master/detail. Use landscape width for simultaneous list and preview/detail surfaces.
- Implementation consequence: Option A is mostly geometry/presentation-mode work. Option B adds a reusable content-width guide and forces decisions about whether header, search header, tag bar, and empty states share the same width. Option C is a new navigation architecture and affects preview entry, back gestures, selection state, direct paste, search ownership, empty states, and transient content transitions.
- Decision: v1 keeps the portrait navigation/layout model: one header, one content container, mutually exclusive content pages. Split master/detail is out of scope for v1.
- Width policy: handled by CL-14. Start with full safe-area width, then decide whether a max-width guide is needed only after visual verification.

Decision CL-13: Compact landscape fullscreen safe-area ownership

- Status: resolved.
- Decision: fullscreen compact landscape should let the blur/background fill the whole panel bounds, while header and content are constrained by `KayokoMainView.contentRespectsSafeArea`.
- Why this matters: this matches the existing fullscreen-search implementation path and avoids inventing a landscape-only safe-area policy.
- Implementation consequence: compact landscape show should set the same safe-area-respecting content mode that portrait fullscreen search already uses; portrait drawer keeps current behavior.

Decision CL-14: Compact landscape single-column width policy

- Status: resolved for v1 implementation; visual verification remains required.
- Why this matters: full-width single-column content is the smallest behavioral change, but a 896pt landscape width may make list rows, search headers, tag bars, text preview, and word-selection chips feel too stretched. A readable width requires a new layout guide that must apply consistently to header, content, search table headers, tag bars, empty states, and transient content.
- Option A: full safe-area width for v1; verify visually and only introduce max width if it is clearly needed.
- Option B: centered max-width column; choose a width cap after an on-device visual probe.
- Option C: biased max-width column; allow the column to sit closer to the thumb side, leaving one side as empty blur.
- Decision: start with full safe-area width because it preserves current layout semantics; decide max-width only after the fullscreen host is technically correct and screenshots/live review show a real readability problem.

## Runtime Research Findings

Finding RF-01: Current passive rotation hide source

- Probe script: `scripts/probes/probe-landscape-rotation-frida.js`.
- Probe target: SpringBoard on iOS 15.0 RootHide.
- Result: while Kayoko was visible, rotation first changed SpringBoard-visible orientation state (`_frontMostAppOrientation` became `landscapeRight`, and `UIScreen.mainScreen.bounds` changed from `414x896` to `896x414`).
- Result: `UIWindowWillRotateNotification` was posted with `panelVisible=YES` before the first hide.
- Result: the first proven hide call was `KayokoSpringBoardHookInstaller hideForLayoutStateTransition`, reached from `SBMainSwitcherViewController layoutStateTransitionCoordinator:transitionDidBeginWithTransitionContext:`.
- Result: later `CoreHide` Darwin notifications also reached `kayokoCoreHideCallback`, but they arrived after the layout-transition hide had already started or after `panelVisible` was already `NO`.
- Result: SpringBoard Helper observed `UIKeyboardWillHideNotification`, but the SpringBoard Helper instance did not call `postCoreHide` in the captured path.
- Interpretation: the current "rotation hides Kayoko" behavior is a side effect of SpringBoard layout transitions, not an intentional rotation-hide path.

Finding RF-02: Rotation callback candidate

- `UIWindowWillRotateNotification` is available in SpringBoard and arrives while Kayoko is still visible.
- It arrives before the layout-transition hide hook.
- It is a narrower rotation signal than reusing the app-switcher/layout transition hook as the primary rotation mechanism.
- Recommended implementation direction: add a rotation observer that hides through Kayoko's existing hide chain with the rotation fade animation. Keep the existing layout-transition hide as a fallback/no-op if the rotation observer already started hiding.

Finding RF-03: SpringBoard host window geometry in landscape

- Probe script: `scripts/probes/probe-springboard-windows-frida.js`.
- Probe target: SpringBoard on iOS 15.0 RootHide.
- Result: when the frontmost app and `UIScreen.mainScreen.bounds` were landscape (`896x414`), the SpringBoard scene itself still reported portrait orientation.
- Result: the current Kayoko view was installed in `UIStatusBarWindow` at level `999`; that window remained `414x896` in landscape.
- Result: most existing SpringBoard windows also remained `414x896` in landscape. `UITextEffectsWindow` did become `896x414`, but it is keyboard/text-effects infrastructure and is not a stable host for Kayoko content.
- Result: a temporary Kayoko-owned `UIWindow` attached to the same `SBWindowScene` could hold a `896x414` frame/bounds in landscape without making the scene itself landscape.
- Interpretation: keeping compact-landscape Kayoko inside `UIStatusBarWindow` would require manual coordinate/transform work inside a portrait window. A Kayoko-owned overlay window is technically feasible and gives the panel a real landscape coordinate space.

Finding RF-04: Overlay root view and safe-area probe status

- Probe script: `scripts/probes/probe-landscape-overlay-safearea-frida.js`.
- Probe target: SpringBoard on iOS 15.0 RootHide.
- Result: in the current portrait run, a temporary Kayoko-owned `UIWindow` attached to `SBWindowScene` was not key, held the expected `414x896` frame/bounds, and its root view reported safe-area insets `{top=48, left=0, bottom=34, right=0}`.
- Result: the temporary root view's `supportedInterfaceOrientations` mask was `30`, which includes landscape orientations.
- Result: in the compact-landscape rerun, a temporary overlay attached to `SBWindowScene` reported landscape safe-area insets `{top=0, left=48, bottom=21, right=48}`.
- Result: when the temporary overlay was only given its screen-bounds frame before being shown, UIKit adjusted it back into a portrait-sized frame. This did not invalidate the safe-area result, but it means the show sequence must explicitly restore the frame after visibility changes.
- Interpretation: the overlay-root path reports meaningful compact-landscape safe-area insets in SpringBoard. A dedicated SpringBoard scene safe-area resolver is not required up front.

Finding RF-05: Reference SpringBoard independent-window implementation

- Reference source: user-provided SpringBoard implementation.
- Relevant pattern: capture a `UIWindowScene` from a visible `UIStatusBarWindow`/`SBStatusBarWindow`, create an independent `UIWindow` with `initWithWindowScene:`, assign a root view controller, set `frame = UIScreen.mainScreen.bounds`, and set `clipsToBounds = YES`.
- Relevant reason for `clipsToBounds`: it prevents visual black edges during rotation animation.
- Reference-specific behavior not copied directly for Kayoko v1: `userInteractionEnabled = NO`, `_ignoresHitTest`, secure-context/capture hiding, `windowLevel = CGFLOAT_MAX`, and always using `makeKeyAndVisible`. Kayoko is interactive, has search, and should preserve current layering semantics instead of becoming a topmost non-interactive secure overlay.

Finding RF-06: Compact-landscape overlay show sequence

- Probe script: `scripts/probes/probe-landscape-window-presentation-frida.js`.
- Probe target: SpringBoard on iOS 15.0 RootHide.
- Result: `hidden = NO` without resetting the frame after showing produced a portrait-sized window frame in compact landscape.
- Result: `hidden = NO` followed by another `setFrame:UIScreen.mainScreen.bounds` produced a non-key `896x414` window with compact-landscape safe-area insets `{top=0, left=48, bottom=21, right=48}`.
- Result: `makeKeyAndVisible` alone did not fix the geometry; `makeKeyAndVisible` plus a post-show frame reset did. Therefore, key-window status is not the geometry fix.
- Decision implication: Kayoko can avoid `makeKeyAndVisible` during normal show and still get correct compact-landscape geometry by setting the overlay frame after the window becomes visible.

## Overlay Window Implementation Decisions

Decision OW-01: Owner of landscape overlay infrastructure

- Status: resolved and implemented.
- Decision: `KayokoCoreRuntime` owns the current portrait status-bar host, the portrait outside-dismiss overlay, and the compact-landscape overlay window. `KayokoSpringBoardHooks` should only discover the status-bar window and deliver lifecycle signals such as rotation.
- Why this matters: runtime already owns the main view controller, visibility state, height preference application, focus restore request, and style application. Splitting window ownership into hook code would make show/hide and rehost ordering harder to reason about.
- Implementation consequence: replace `installPanelInStatusBarWindow:` with an install/update method that stores the host window, creates the main controller once, and can move the controller view between hosts while hidden.

Decision OW-02: Overlay window class

- Status: resolved for implementation; search-keyboard behavior is a post-implementation validation item.
- Decision: do not force `canBecomeKeyWindow == NO`. The compact-landscape overlay must not be made key as part of the normal show path, but it must remain eligible for UIKit text focus if search activation requires the panel window to become key.
- Why this matters: fullscreen landscape search still uses `UISearchBar` and keyboard input. A window that can never become key may prevent the search bar from becoming first responder or prevent the keyboard from routing input to Kayoko.
- Existing cleanup evidence: `KayokoMainViewController -hideWithCompletion:` calls `KayokoSearchController -resetBeforeHide`, and active search ending calls `resignFirstResponder` on the active search bar.
- Implementation consequence: the first implementation should use a normal `UIWindow` or a minimal subclass that does not override key-window eligibility. Do not call `makeKeyWindow` or `makeKeyAndVisible` during show. Search activation is allowed to change key-window/focus state through UIKit's normal text-input path, matching portrait semantics. The implemented subclass only passes touches through while the Kayoko root view is still hidden.
- Post-implementation validation: if compact-landscape search does not bring up a usable keyboard, the fallback decision is to allow a targeted key-window transition only when search starts, then rely on existing search/hide cleanup to resign first responder.

Decision OW-03: Main controller reuse

- Status: resolved and implemented.
- Decision: reuse the existing single `KayokoMainViewController` instance and move it to the active host. Do not create a second landscape-specific controller tree.
- Why this matters: the main controller owns history/favorites controllers, search controller, preview/word-selection controllers, transient state cleanup, and focus-restore callbacks. Duplicating it would introduce state synchronization and paste/search regressions for no v1 product benefit.
- Implementation consequence: host switching must happen only while the panel is hidden or immediately before a show. Visible rotation hides first; it does not live-reparent the visible view.

Decision OW-04: Overlay root view controller shape

- Status: resolved and implemented.
- Decision: in compact landscape, set the existing `KayokoMainViewController` as the overlay window's `rootViewController`. In portrait, keep the existing direct subview installation in `UIStatusBarWindow`.
- Why this matters: using the main controller as the overlay root is the smallest standard UIKit window shape and lets the main view receive root-view safe-area propagation. A separate container root controller is only justified if landscape probes show root safe-area/orientation issues.
- Implementation consequence: when switching back to portrait, clear the overlay window's `rootViewController` while hidden, then add the main controller view back to the status-bar host.

Decision OW-05: Host switching timing

- Status: resolved and implemented.
- Decision: choose and apply the active host before each show. If Kayoko is visible during rotation, hide with the existing hide pipeline first, then leave rehosting to the next show or hide completion.
- Why this matters: the current hide completion already resets search/transient content. Moving the view while visible would create extra ordering problems around animations, keyboard first responder state, and content transitions.
- Implementation consequence: the runtime needs an `ensurePanelHostForPresentationMode:`-style helper that cancels panel animations, resets transform/alpha/frame, and applies the expected host geometry while hidden.

Decision OW-06: Overlay window lifecycle

- Status: resolved and implemented.
- Decision: create the overlay window lazily on first compact-landscape show, keep it retained while hidden, set `clipsToBounds = YES`, update its frame from `UIScreen.mainScreen.bounds` before and after making it visible, and recreate/rebind it if the stored status-bar host's `windowScene` changes.
- Why this matters: creating/destroying the window every show adds churn, but keeping it visible while hidden would intercept touches.
- Implementation consequence: `hide` and `hideImmediately` must hide the overlay window after the main panel hide completes when the active host is compact landscape.

Decision OW-07: Overlay frame and level source

- Status: resolved.
- Decision: compact-landscape overlay frame follows `UIScreen.mainScreen.bounds`, not `UIStatusBarWindow.bounds`. Its level follows the current status-bar host window level, with a conservative fallback around `UIWindowLevelStatusBar`/`999`.
- Why this matters: probes showed `UIStatusBarWindow` remains portrait-sized in compact landscape, while a Kayoko-owned window can hold the landscape screen bounds. Matching the status-bar level preserves Kayoko's current layering relationship.

Decision OW-08: Outside-dismiss overlay ownership

- Status: resolved and implemented.
- Decision: keep the outside-dismiss overlay only for portrait drawer mode. In compact landscape, set the panel presentation controller's outside overlay to `nil` or an inert hidden reference.
- Why this matters: there is no outside region in compact-landscape fullscreen. Carrying the portrait overlay into the landscape window would add an invisible control layer with no product purpose.
- Implementation consequence: `KayokoPanelPresentationController` must tolerate a nil outside overlay in all show/hide/pan paths.

Decision OW-09: Presentation mode as a shared technical contract

- Status: resolved and implemented.
- Decision: introduce a small presentation-mode enum, with at least `portraitDrawer` and `compactLandscapeFullscreen`, and pass it into runtime, panel presentation, search presentation, and main view safe-area decisions.
- Why this matters: branching on raw orientation in each controller would couple unrelated behavior and make portrait regressions more likely.
- Implementation consequence: `HeightInPoints`, outside dismiss, search frame expansion, content safe area, and hide animation style all read the same presentation mode.

Decision OW-10: Safe-area ownership across search begin/end

- Status: resolved and implemented.
- Decision: make compact-landscape safe-area mode presentation-owned, not search-owned. Search begin/end may reveal/hide search UI and change filtering state, but it must not set `contentRespectsSafeArea` back to `NO` while the panel is in compact-landscape fullscreen.
- Why this matters: current portrait fullscreen search owns `contentRespectsSafeArea`: begin search sets it to `YES`, end search resets it to `NO`. In compact landscape, fullscreen is the base presentation, so search end cannot restore drawer safe-area behavior.
- Implementation consequence: `KayokoSearchPresentationController` needs presentation-mode awareness or a callback to ask whether ending search should restore the pre-search frame/safe-area mode.

Decision OW-11: Hide animation style plumbing

- Status: resolved and implemented.
- Decision: keep one hide pipeline, but add a hide animation style parameter. Normal compact-landscape dismiss uses fullscreen slide/fade; rotation-triggered dismiss uses fade; focus restoration remains controlled by the existing caller semantics.
- Why this matters: product decisions require different animations for normal fullscreen dismissal and rotation dismissal, but rotation must not become a separate focus-restoration or cleanup path.
- Implementation consequence: add a panel hide style at the presentation layer rather than adding rotation-specific cleanup branches in runtime or main controller.

Decision OW-12: Missing landscape host fallback

- Status: resolved and implemented.
- Decision: if compact landscape is requested but no usable status-bar host/window scene is available to create the overlay, fail the show request with the existing failure feedback instead of displaying inside the portrait-sized status-bar window.
- Why this matters: probes showed the portrait status-bar host cannot produce correct compact-landscape fullscreen geometry. Falling back to that host would produce a visibly wrong panel and hide the real host failure.
- Implementation consequence: the current `frontmostAppIsLandscape` rejection is replaced by a host-preparation failure only when compact landscape cannot be hosted.

Decision OW-13: Presentation-mode orientation resolver

- Status: resolved and implemented.
- Decision: use `UIApplication _frontMostAppOrientation` as the primary signal for compact landscape mode, gated to iPhone/compact phone scope. Do not infer compact-landscape mode from `UIStatusBarWindow.bounds`.
- Why this matters: probes showed the status-bar window stays portrait-sized in compact landscape, so host-window geometry is a bad orientation signal. `_frontMostAppOrientation` changed to landscape before the rotation hide path fired.
- Implementation consequence: compact landscape frame geometry uses `UIScreen.mainScreen.bounds`, but the decision to enter compact-landscape fullscreen comes from `_frontMostAppOrientation`. If `_frontMostAppOrientation` is unavailable, use screen bounds only as a conservative fallback and fail safely if host preparation cannot produce a landscape overlay.

## Technical Verification Items

These items are not blockers for starting implementation. They should be verified against the implemented compact-landscape surface, and only reopened for deeper probing if the implementation exposes a concrete failure.

Question TR-01: What is the authoritative compact-landscape signal in SpringBoard?

- Why it matters: `KayokoCoreRuntime` currently uses `_frontMostAppOrientation` only to reject landscape. Fullscreen landscape support needs a resolver for "compact landscape fullscreen" that is correct when the panel lives in `UIStatusBarWindow` and the frontmost context is a foreground app, SpringBoard, or Spotlight.
- Evidence found: `_frontMostAppOrientation` changes to landscape while the status-bar host and SpringBoard scene can remain portrait-sized. `UIScreen.mainScreen.bounds` also changes to landscape, but it is frame geometry rather than the semantic frontmost app orientation.
- Proposed decision: use `_frontMostAppOrientation` as the primary presentation-mode resolver; use `UIScreen.mainScreen.bounds` for compact-landscape overlay frame geometry.

Question TR-02: Which event reliably detects rotation while Kayoko is visible?

- Why it matters: product behavior is to hide Kayoko instead of relaying out the visible surface. The implementation needs a reliable trigger before UIKit has a chance to leave the panel in a stale frame.
- Evidence found: `UIWindowWillRotateNotification` arrives before the first current passive hide, and `_frontMostAppOrientation` has already changed by that point.
- Proposed decision: observe `UIWindowWillRotateNotification` in SpringBoard and hide once through the normal Kayoko hide chain using the rotation fade animation.

Question TR-03: Which existing passive hide path fires during rotation?

- Why it matters: the current product already appears to hide Kayoko on rotation without an explicit rotation hook. If this path is stable, landscape support can reuse it rather than add a duplicate hide trigger.
- Static candidates: Helper `UIKeyboardWillHideNotification`, Helper `UIWindowDidResignKeyNotification`, Helper keyboard view `didMoveToWindow`, SpringBoard `FBScene updateSettings`, status-bar/window visibility callbacks, and app switcher/layout transitions.
- Evidence found: the first proven hide source is SpringBoard `hideForLayoutStateTransition`, called from `SBMainSwitcherViewController layoutStateTransitionCoordinator:transitionDidBeginWithTransitionContext:`.
- Decision after evidence: do not treat the layout-transition hook as the primary rotation design. It can remain a fallback for other SpringBoard transitions and duplicate rotation events.

Question TR-04: If an explicit rotation fallback is needed, where is the smallest correct hook?

- Why it matters: adding a broad observer would make rotation feel like a special lifecycle outside the existing hide model. The fallback should only compensate for a proven missing signal.
- Evidence needed: compare ordering and availability of `FBScene updateSettings`, `UIWindowScene` geometry/bounds changes, `UIStatusBarWindow` frame changes, and `KayokoMainView` layout callbacks during portrait-to-landscape and landscape-to-portrait rotation.
- Decision after evidence: choose one fallback hook or reject the fallback if existing `CoreHide` delivery is stable.

Question TR-05: Which window should host compact-landscape Kayoko?

- Why it matters: the current `UIStatusBarWindow` host remains portrait-sized in landscape, so fullscreen compact-landscape layout cannot be treated as a simple frame change inside the existing host.
- Evidence found: `UIStatusBarWindow` remains `414x896` while `UIScreen.mainScreen.bounds` is `896x414`; a Kayoko-owned temporary `UIWindow` can hold `896x414` in the same SpringBoard scene.
- Decision: keep the current status-bar host for portrait, but create a Kayoko-owned overlay window for compact landscape. The show path must not actively make that window key.

Question TR-06: Should the compact-landscape overlay window become key?

- Why it matters: making the window key could disturb the focused app/keyboard responder chain. The current portrait implementation does not make a new key window; it adds views to an existing SpringBoard window.
- Corrected decision: do not call `makeKeyWindow` or `makeKeyAndVisible` during normal show. Do not prevent the window from becoming key if UIKit needs that for `UISearchBar` first-responder/search input. Focus restoration remains controlled by the existing session semantics.

Question TR-07: What window level should compact-landscape Kayoko use?

- Why it matters: the window must sit above app/home content but should not fight alerts, Control Center, Cover Sheet, or keyboard/text-effects windows.
- Evidence found: current Kayoko host is `UIStatusBarWindow` at level `999`; `UITextEffectsWindow` was around `1058`, Control Center around `1080`, banners around `1090`, screenshots around `1115`, alerts around `2000`.
- Decision: use the status-bar window level or just below it for the compact-landscape Kayoko overlay, preserving current relative layering and keeping keyboard/system overlays above it.

Question TR-08: How should compact-landscape safe-area insets be sourced?

- Why it matters: iPhone landscape safe areas are primarily lateral plus the home indicator edge. If the Kayoko-owned overlay window reports correct safe areas, `contentRespectsSafeArea` can carry most of the work; if it reports zero because SpringBoard's scene remains portrait, Kayoko needs a targeted landscape safe-area resolver.
- Evidence found: portrait and compact-landscape overlay root safe-area values are meaningful. Compact landscape reported `{top=0, left=48, bottom=21, right=48}`.
- Decision: rely on the overlay window plus `contentRespectsSafeArea`. Add a SpringBoard-scene safe-area resolver only if the implemented Kayoko surface shows a concrete overlap.

Inherited Path Verification VP-01: safe area

- Current rule: inherit the existing scene-scoped safe-area model. Do not invent a landscape-only safe-area source.
- Verification needed: after fullscreen compact landscape exists, check whether existing content constraints and same-scene safe-area helpers keep controls, lists, preview, and word selection clear of unsafe edges.
- Follow-up only if broken: generalize the existing helper in `KayokoMainView`; do not add a separate landscape policy.

Inherited Path Verification VP-02: search keyboard inset

- Current rule: inherit the existing keyboard frame conversion and bottom-overlap inset path.
- Verification needed: after search works in compact landscape, confirm the list remains usable with the keyboard shown.
- Follow-up only if broken: fix the shared inset calculation with evidence from keyboard frame/container intersection logs.

Inherited Path Verification VP-03: focus restoration

- Current rule: focus restoration is session semantics, not rotation semantics. Rotation should not add restore-focus branches.
- Verification needed: make sure rotation-triggered hide enters the same hide path as other hide reasons and does not bypass existing focus behavior.

Inherited Path Verification VP-04: activation and gesture regions

- Current rule: all existing activation methods remain allowed in compact landscape, and existing system-gesture suppression remains category-based.
- Verification needed: test activation methods after the fullscreen layout exists. Only fix a recognizer/region if a concrete activation path fails.

## Agent-Owned Implementation Notes

- Use a presentation-mode enum rather than scattered compact-landscape booleans.
- Keep `HeightInPoints` loaded normally and ignore it only while compact landscape fullscreen mode is active.
- Put frame-animation branching in presentation owners (`KayokoPanelPresentationController` and `KayokoSearchPresentationController`) rather than in data/search coordinators.
- Treat outside-dismiss overlay as an implementation detail that becomes a no-op when there is no outside region.
- Rehost the existing main view controller while hidden; do not create a second landscape controller tree.
- Hide the compact-landscape overlay window after the panel hide completion, not before the panel animation finishes.
- Keep rotation-triggered fade as an animation style inside the existing hide pipeline, not as a separate cleanup/focus path.
- Do not introduce compact-landscape-only product UI unless a probe exposes a concrete unusable state.

## Implementation Plan

Phase 0: runtime probes

- Status: completed enough for implementation.
- Verified `_frontMostAppOrientation` and screen bounds update during rotation.
- Verified the first current hide source while Kayoko is visible.
- Identified `UIWindowWillRotateNotification` as the proposed rotation-hide trigger.
- Verified compact-landscape overlay safe-area values on the target device.
- Verified the compact-landscape overlay show sequence needs a post-visibility frame reset, not `makeKeyAndVisible`, to get correct geometry.
- Keep safe-area, keyboard inset, focus restoration, and activation gestures as inherited-path verification items, not preemptive redesign topics.

Phase 1: presentation mode and geometry

- Status: implemented; package build passed.
- Add a central presentation-mode decision: portrait drawer vs compact landscape fullscreen.
- Store/update the portrait status-bar host window in runtime.
- Add a compact-landscape overlay window that is lazy, clipped to bounds, not actively made key during show, hidden when not in use, and attached to the stored status-bar host's window scene.
- Replace direct `HeightInPoints` frame construction with a geometry helper.
- In compact landscape, move/show Kayoko inside the Kayoko-owned overlay window whose frame follows `UIScreen.mainScreen.bounds`, and ignore `HeightInPoints`.
- Set the overlay frame from `UIScreen.mainScreen.bounds` before showing and again immediately after making the window visible.
- Rehost only while hidden or before show; reset transform/alpha/frame before showing in the new host.
- Keep portrait frame calculation behavior unchanged.

Phase 2: rotation handling

- Status: implemented; on-device behavior still needs validation.
- Observe `UIWindowWillRotateNotification` in SpringBoard while Kayoko is visible.
- If visible, hide through the existing hide chain using the rotation-hide fade animation style instead of applying a new visible frame.
- Keep `hideForLayoutStateTransition` as a fallback for SpringBoard transitions, but make duplicate hides harmless when rotation already started hiding Kayoko.
- If hidden, update geometry lazily before the next show.

Phase 3: fullscreen compact landscape panel behavior

- Status: implemented; on-device behavior still needs validation.
- Teach `KayokoPanelPresentationController` the current presentation mode.
- Keep the portrait downward-pan dismissal logic unless probes show a concrete compact-landscape conflict.
- Treat outside-dismiss overlay behavior as a no-op in compact landscape because there is no outside region.
- Add hide animation style plumbing so normal compact-landscape dismiss can slide/fade while rotation dismiss can fade.
- Hide the overlay window after normal/rotation hide completion.
- Keep portrait show/hide and pan behavior unchanged.

Phase 4: search behavior

- Status: implemented; compact-landscape keyboard behavior still needs validation.
- Teach `KayokoSearchPresentationController` the current presentation mode.
- In compact landscape, make begin/end search no-op for frame changes.
- In compact landscape, search end must not reset `KayokoMainView.contentRespectsSafeArea` to portrait drawer mode.
- Keep search state, token headers, filtering, first responder, keyboard insets, and cancel behavior working.
- Disable fullscreen-pan collapse handling in compact landscape.

Phase 5: safe area and layout

- Status: implementation uses overlay-root safe areas; visual validation still required.
- Verify the implemented overlay-root safe-area path in compact landscape before adding any fallback resolver.
- Ensure history/favorites list content and scroll indicators avoid compact landscape safe areas; only adjust the shared helper if verification shows overlap.
- Ensure preview and word-selection tag bars avoid compact landscape safe areas through their existing container constraints or targeted updates; only add targeted updates if verification shows overlap.
- Verify no text or controls overlap in compact landscape with the keyboard hidden and shown.

Phase 6: validation

- Status: partially complete.
- Build with root `gmake`. Completed.
- Build RootHide package. Completed.
- Verify portrait regression: show, hide, search fullscreen, preview, word selection, direct paste.
- Verify compact landscape: show, dismiss, History/Favorites switch, search, token filters, preview text, preview image zoom, word selection, tag bar, automatic paste.
- Verify rotation while visible hides Kayoko.
- Verify activation methods in compact landscape according to CL-06.

## Non-Goals For First Pass

- iPad-specific layout.
- Side panel presentation.
- New preference UI for landscape size.
- Reworking Kayoko's data, pasteboard, tagging, or purchase authorization flows.
- Changing existing portrait presentation semantics.
