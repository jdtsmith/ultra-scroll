# ultra-scroll: scroll emacs like lightning ⚡🖱️⚡

<a href="https://melpa.org/#/ultra-scroll"><img alt="MELPA" src="https://melpa.org/packages/ultra-scroll-badge.svg"/></a>

`ultra-scroll`[^1] is a smooth-scrolling package for emacs, with native
support for standard builds as well as
[emacs-mac](https://bitbucket.org/mituharu/emacs-mac). It provides
highly optimized, pixel-precise smooth scrolling which can readily keep
up with the *very* high event rates of modern track-pads and
high-precision wheel mice.

You move your fingers, the page responds, *instantly*:

<https://github-production-user-asset-6210df.s3.amazonaws.com/93749/290018933-ed5cf414-eab5-4ba8-b077-30cac0c5ace0.mov>

Importantly, `ultra-scroll` can cleanly *scroll right across* tall
images and other jumbo lines – a perennial problem with scrolling
packages to date. As a bonus, it enables relatively smooth scrolling
even with dumb third party mice.

Note, the `previous-buffer` animation above is from two-finger track-pad
swiping, and is an [emacs-mac](https://github.com/jdtsmith/emacs-mac)
exclusive.

> [!NOTE]
> **Do you need this?**
>
> If you don't scroll with a high-speed device (modern mouse or
> track-pad), no. If you do, but aren't sure, here's a good test to try:
>
> Open a heavy emacs buffer full screen on your largest monitor. While
> scrolling smoothly such that lines would move across your window's
> full height in about 5 seconds, *can you easily read the text you
> see*, without stopping, in both directions? Now, try this exercise
> again with your browser – I bet it's *very* readable there. Shouldn't
> emacs be like this?
>
> In addition, if you scroll buffers with tall images visible, this is
> also a good reason to give `ultra-scroll` a try.

## Release Information

See the [NEWS](./NEWS.org).

## Compatibility

`ultra-scroll` should work across all systems that provide pixel-level
scrolling information for your input hardware. If you don't think
`ultra-scroll` is working for you, run `M-x ultra-scroll-check`, and
follow the directions. If it reports:

- **Normal pixel scroll data**: you are good to go, everything is
  working.
- **No real pixel scroll data**: your system and hardware are delivering
  pixel scrolling data, but they *never change* (test again to be sure).
  This is equivalent to line-by-line scrolling. `ultra-scroll` will work
  fine for you, but *without* any smooth scrolling. You can use it for
  the improved large image scrolling behavior, or see below for another
  option.
- The *error* **Malformed wheel event**: your system does not deliver
  *any* pixel-level scroll data. Either upgrade your hardware/system to
  a known working config (see [this issue](../../issues/18) and the
  [discussions](../../discussions) for user experiences). Or see below
  for an alternative.

For systems which do *not* provide normal pixel scroll data, you can try
the built-in `pixel-scroll-precision-mode` with
`pixel-scroll-precision-interpolate-mice` (which "creates" events by
interpolation) instead.

> [!IMPORTANT]
> **Your Help Needed!** While `ultra-scroll` works out of the box for
> most people, it's impossible to test all combinations of systems and
> hardware, so please take a moment to [report your smooth-scrolling
> experiences](../../discussions).

## Installation

`ultra-scroll` is in MELPA. Starting from Emacs 30, you can also use the
new `:vc` keyword to download directly from this repository.
Configuration is then simple:

``` commonlisp
(use-package ultra-scroll
  ;:vc (:url "https://github.com/jdtsmith/ultra-scroll") ; if desired (emacs>=v30)
  :init
  (setq scroll-conservatively 3 ; or whatever value you prefer, since v0.4
        scroll-margin 0)        ; important: scroll-margin>0 not yet supported
  :config
  (ultra-scroll-mode 1))
```

## Usage

Just start scrolling 😎.

> [!TIP]
> For best performance, use a build of Emacs with native-compilation
> (see [Speed](#Speed)).

## Configuration

There is little to no configuration necessary.

### Altering dumb mice behavior on emacs-mac

If desired for use with dumb mice on `emacs-mac`, the variable
`ultra-scroll-mac-multiplier` can be set to a number smaller or larger
than `1.0` to decrease/increase mouse-wheel scrolling speed. Note that
many fancier wheeled mice have drivers that *simulate* track-pads, so
this variable will have no effect on them. For these, and for track-pads
generally, scrolling speed should be configured in system settings.

> [!NOTE]
> Only certain systems provide real variable pixel scroll offset data
> (`PIXEL-DELTA`) for older/wheeled ("dumb") mice. Use
> `M-x ultra-scroll-check` to see if yours does. If not, it's
> recommended to upgrade hardware, or stick with
> `pixel-scroll-precision-mode`.

### Mitigating garbage collection pauses

To reduce the likelihood of garbage collection during scroll, which can
introduce slight pauses, the value of `gc-cons-percentage` is
temporarily increased, and reset during idle time. The defaults should
work well for most situations, but if necessary, can be configured using
`ultra-scroll-gc-percentage` and `ultra-scroll-gc-idle-time`.

### Hiding cursor, and disabling other modes during scroll

By default, `ultra-scroll` hides the cursor (and a `hl-line` if active)
once it reaches the window edge, to prevent "bouncing cursor" behavior.
This can be disabled, or the time delay to restore the cursor set, with
`ultra-scroll-hide-cursor`.

In addition to the cursor, it is sometimes useful to temporarily disable
other modes during the scroll. The special hook variable
`ultra-scroll-hide-functions` can be used for this, e.g.:

``` commonlisp
(add-hook 'ultra-scroll-hide-functions 'hl-line-mode)
```

By default, the hook contains `hl-line-mode`.

### Restoring the column

You can optionally enable restoring the visual column position after the
scroll completes; see `ultra-scroll-preserve-column`. Note that this
require cursor hiding to be enabled.

## `pixel-scroll-precision` comparison and interoperability

Emacs has a built-in smooth scrolling mode called
`pixel-scroll-precision-mode`. In fact, by design, `ultra-scroll`
*activates* the builtin `pixel-scroll-precision-mode`, remapping its
scrolling function with its own. The latter also has the capability of
*faking* smooth scrolling using interpolation. It can do this for
non-mouse movements, like `scroll-up/down-command` (usually on `PgUp` /
`PgDown`). To use these additional capabilities, simply set the relevant
variables, like `pixel-scroll-precision-interpolate-page`, and they
should "just work".

Note that `ultra-scroll` disables `pixel-scroll-precision-use-momentum`,
since it may not handle tall image scrolling well. Some systems (MacOS)
get momentum scrolling "for free" from the OS, independent of this
setting. If you experiment with re-enabling
`pixel-scroll-precision-use-momentum` on other systems like Linux,
please start a [discussion](../../discussions) to report your findings.

> [!WARNING]
> `ultra-scroll` activates `pixel-scroll-precision-mode` by *side
> effect*. If you are experimenting with both modes during a single
> session, always disable `ultra-scroll-mode` first and then re-enable
> `pixel-scroll-precision-mode`.

### A comparison between ultra-scroll and pixel-scroll-precision

See also [this
question](#how-does-this-compare-to-the-built-in-smooth-scrolling).

`pixel-scroll-precision-mode`:

- Supports smooth scrolling even on systems which do *not* provide real
  pixel scroll data, using interpolation (see
  `pixel-scroll-precision-interpolate-mice`).
- Can simulate a "momentum" scrolling phase on systems which do not
  provide this capability (see `pixel-scroll-precision-use-momentum`).
- Has occasional issues scrolling tall images.

`ultra-scroll`:

- Fully supports *only* those system and hardware combos that deliver
  *real* pixel scroll data (see [Compatibility](#Compatibility)).
- Provides "momentum" scrolling only on systems which provide this
  themselves.
- Is somewhat faster (see [Speed](#Speed)).
- Handles tall image scrolling without issue.

## Related packages and functionality

emacs-mac's own builtin `mac-mwheel-scroll`  
This venerable code by Mitsuharu Yamamoto was introduced with
[emacs-mac](https://bitbucket.org/mituharu/emacs-mac/) more than a
decade ago, and was the very first to provide smooth pixel scrolling in
any version of emacs.

`pixel-scroll-precision-mode`  
A fast pixel scrolling by Po Lu, built in to Emacs as of v29.1 (see
`pixel-scroll.el`). Does not support `emacs-mac`. `ultra-scroll` was
initially based on its design, but many design elements have changed.

`pixel-scroll-mode`  
A simpler line-by-line pixel scrolling mode, also found in the file
`pixel-scroll.el`.

[good-scroll](https://github.com/io12/good-scroll.el)  
An update to `pixel-scroll-mode` with variable speed.

[sublimity](https://github.com/zk-phi/sublimity)  
Implements smooth scrolling based on the sublime editor.

## Questions

### What was the motivation behind this?

Picture it: a fast new laptop and 5K monitor with a large heavy-duty,
full-screen buffer in `python-ts-mode`. Scrolling line-by-line with a
decent mouse is mostly OK, but smooth pixel scrolling with the track-pad
is just… *painful*. Repeated attempts to rationalize this fail,
especially because it's notably worse in one direction than the other.
Scrolling Emacs feels like moving through (light) molasses. *No bueno*.

Checking into it, the smooth scroll event callback takes 15-20ms
scrolling in one direction, and 3–5x longer in the other. This
performance is perfectly fine for normal mice which deliver a few
scrolling events a second. *But track-pad and fancy mouse scroll events
are arriving every 10ms, or less*! The code just couldn't keep up.
Hence: molasses.

I also wanted to be able to scroll through image-rich documents without
worrying about jumpy/loopy scrolling behavior. And my extra dumb mouse
didn't work well either: small scrolls did nothing: you'd have to scroll
pretty aggressively to get any movement at all.

How hard could it be to fix this? And the adventure began…

### Why was this initially for emacs-mac only?

This packaged used to be called `ultra-scroll-mac`. The `emacs-mac` port
of emacs exposes pixel-level scrolling event stream of Mac track-pads
(and other fancy mice) in a distinct way, which is not supported by
`pixel-scroll-precision-mode`. And unfortunately the default
smooth-scrolling library included in `emacs-mac` has somewhat low
performance (see above).

### How does this compare to the built-in smooth scrolling?

On the `emacs-mac` build, there is no comparison, because
`pixel-scroll-precision-mode` doesn't work there. On other builds, they
are fairly comparable. Compared to `pixel-scroll-precision-mode`,
`ultra-scroll` obviously works with `emacs-mac`, but is also even
[faster](#Speed), and can cleanly scroll past images taller than the
window.

In addition to fast scrolling, the built-in
`pixel-scroll-precision-mode` (new in Emacs v29.1) can simulate a
*feature-complete track-pad driver* in elisp for older mice or systems
which do not supply pixel scroll information. This comes complete with
elisp-based *scroll interpolation*, a timer-based *momentum* phase, etc.

### Why are there so many smooth scrolling modes? Why is this so hard? It's just *scrolling*…

Emacs was designed long before mice were common, not to mention modern
high-resolution track-pads and mice which send rapid micro-updates
("move up one pixel!") 60-120 times per second. Unlike other programs,
Emacs *insists* on keeping the cursor (point) visible at all times. Deep
in its re-display code, Emacs tracks where point is, and works
diligently to ensure it never falls outside the visible window. It does
this *not* by moving point itself (that's the user's job), but by moving
the *window* (visible range of lines) surrounding point.

Once you are used to this behavior, it's actually pretty nice for
navigating with `C-n` / `C-p` and friends. But for smooth scrolling with
a track-pad or mouse, it is *very problematic* – nothing screams "janky
scrolling" like the window lurching back or forth half a page during a
scroll. Or worse: getting caught in an endless loop of
scroll-in-one-direction/jump-back-in-the-other.

So what should be done? The elisp info manual (`Textual Scrolling` /
`set-window-start`) helpfully mentions:

> …for reliable results Lisp programs that call this function should
> always move point to be inside the window whose display starts at
> POSITION.

Which is all well and good, but *where* do you find such a point, in
advance, safely *inside the window*? Often this isn't terribly hard, but
there is one common case where this admonition falls comically flat:
scrolling past an image or other content which is *taller than the
window* – what I call **jumbo lines**. Where can I place point *inside
the window* when a jumbo line occupies the entire window height?

As a result of these types of difficulties, pixel scrolling codes and
packages are often quite involved, with much of the logic boiling down
to a stalwart and increasingly heroic pile of interwoven attempts to
*keep the damn point on screen* and prevent juddering and looping as you
scroll.

### What should I know about developing scrolling modes for Emacs?

For posterity, some things I discovered in my own mostly-victorious
battle against unwanted re-centering during smooth scroll, including
across jumbo lines:

- `scroll-conservatively=101` is very helpful, since with this Emacs
  will "scroll just enough text to bring point into view, even if you
  move far away". It does not defeat re-centering, but makes it… more
  manageable.
- You cannot let-bind `scroll-conservatively` for effect, as it comes
  into play only on re-display (after your event handler returns). But
  (I discovered later) you *can* set it *temporarily* and restore it
  during idle time without ill effect.
- `scroll-margin>0` is a no-no. This setting always moves point at least
  that many lines away from the window boundaries, which, unless you can
  reliably place point there during the scroll (even in the presence of
  *jumbo lines*; see below), will cause loop-back. See \#3.
- Virtual Scroll:
  - `vscroll` – a virtual rendered scrolling window hiding *below* the
    current window – is key to smooth scrolling, and altering `vscroll`
    to move the view-port is incredibly fast.
  - There is plenty of `vscroll` room available, including the entirety
    of any tall lines (as for displayed images) in view.
  - `vscroll` can sometimes place the point off the visible window (I
    know, sacrilege), but more often triggers re-centering.
- Scrolling asymmetry:
  - Sadly `vscroll` is purely *one-sided*: you can only access a
    `vscroll` area *beneath* the current window view; *there is no
    negative `vscroll`*.
  - Unlike `window-start`, `window-end` does not get updated promptly
    between re-displays and cannot always be trusted. Computing it is
    expensive, so should be avoided during re-display.
  - For these two reasons, smooth scrolling up and scrolling down are
    *not symmetric* with each other, and will likely never be. You need
    different approaches for each.
  - If the two approaches for scrolling up and down perform quite
    differently, the user will definitely feel this difference.
- For avoiding re-centering, naive movement doesn't work well. You need
  to learn the basic layout of lines on the window *before re-display*
  has occurred.
- The "usable window height" deducts any header and the old-fashioned
  tab-bar, but *not* the `tab-bar-mode` bar.
- Jumbo lines (lines taller than the window's height):
  - Scrolling towards buffer end:
    - When scrolling past jumbo lines towards the buffer's end (with
      `vscroll`), simply keep *point on the jumbo line* until it *fully
      disappears* from view. As a special case, Emacs will not re-center
      when this positioning is maintained.
    - This is *not* true for lines that are *shorter* than the usable
      window height (even if they are fairly tall images). In this case,
      you must *avoid* placing point on any line which falls partially
      out of view.
  - Scrolling towards buffer start:
    - When scrolling up past jumbo lines towards the buffer's start
      using `set-window-start` (lines of content move down), you must
      keep point on the jumbo line, but *only until it clears the top of
      the window area* (even by one pixel).
    - After this, you must move the point to the line above it.
    - In some cases (depending on truncation/visual-line-mode/etc.),
      this movement must occur from a position beyond the first full
      height object (which may not be at the line's start). E.g. one
      before the visual line end.
- `pos-visible-in-window` doesn't always give correct results near the
  window boundaries. Better to use the first line at the window's top or
  directly identify the final line (both via `pos-at-x-y`) and adjust
  from there.

So all in all, it's quite complicated to get something that works as
you'd hope. The cutting room floor is littered with literally dozens of
almost-but-not-quite-working versions of `ultra-scroll`. I'm sure there
are many more corner cases, but the current design gets most things
right in my usage.

## Display bugs

`ultra-scroll` exercises some rare corner cases of Emacs' re-display
logic, and as a result has revealed and helped fix quite a number of
display bugs. These bugs lead to behaviors like slightly staccato
scrolling in buffers with diverse line heights (e.g. inline images, à la
`org-mode` with latex previews). If you think you have found a display
bug, feel free to open an issue to discuss.

- A [display bug](https://debbugs.gnu.org/cgi/bugreport.cgi?bug=67533)
  with inline images that cause them to sometimes misreport pixel
  measurements and positions has been fixed in master as of Dec, 2023,
  so scrolling with lots of inline images should be much smoother
  starting from Emacs v30.
- As of June, 2025, another [display
  bug](https://debbugs.gnu.org/cgi/bugreport.cgi?bug=67604) related to
  line-skipping of visual (i.e. word) wrapped lines with inline images
  at line start has been fixed (for Emacs v31). This caused additional
  (but even rarer) "hitches" in smooth scrolling in buffers with
  numerous inline images.
- Another display bug which leads to scrolling (and general UI) slowdown
  in some edge-case situations with `make-cursor-line-fully-visible=t`
  was also [found](../../issues/32) and
  [fixed](https://debbugs.gnu.org/cgi/bugreport.cgi?bug=78766) in
  June, 2025. This fix will be included with Emacs v31.

## Speed

I often wonder how many people who claim "emacs is laggy" form that
impression from scrolling. Scrolling at 60-120Hz or faster with modern
mice and track-pads puts a lot of stress on systems, and is often the
first place lag appears. So `ultra-scroll` is fast *by design*. I made
some observations about its speed using `ELP` to measure the average
call duration of individual scroll functions (`ultra-scroll-up/down`)
with various buffer and window sizes[^2].

### Take-aways

1.  Very large window sizes and buffers with "extra" processing going
    on, like treesitter, LSP modes, elaborate font-locking, tons of
    overlays, etc. can slow down scrolling.
2.  If the scroll command does its work in \<10ms, you do not notice it.
    You can definitely start feeling it when scroll commands take more
    than 15ms.
3.  The underlying scroll primitives need to leave some overhead in
    time, so that all the other emacs commands that occur when new
    content is brought into view (font-lock) can run without causing
    scroll lag, for all your different modes. **Faster is better**: 3ms
    or less[^3] in a light buffer would be *ideal*.
4.  Building `--with-native-comp` is *essential* for ultra-smooth
    scrolling. It increases the speed of each individual scroll command
    by **\>3x**, which is important since these commands are called so
    frequently.
5.  On the exact same build (NS, v29.4, with native-comp),
    `ultra-scroll` is about **40% faster** than
    `pixel-scroll-precision-mode`. Except on slower machines, or in very
    heavy buffers and/or on large window sizes where your performance is
    right on the edge, this shouldn't be too noticeable.
6.  On the same system (an M2 mac), `ultra-scroll` on `emacs-mac` is
    10-15% faster than it is on NS builds like `emacs-plus`. Very likely
    not noticeable.
7.  The mode-line gets updated *very often* during smooth scrolls (and
    in general), and poorly written fancy modeline add-ons are a very
    common source of slow-down. Good modeline modes will *rate-limit*
    their updates behind timers and/or cache results in local/global
    variables. If your scrolling (or any other aspect of Emacs) "lags",
    try `(setq mode-line-format "NADA")` and see if that solves it. If
    so, suspect your fancy modeline.

[^1]: Formerly `ultra-scroll-mac`.

[^2]: To try this yourself, `M-x elp-instrument-function` on both
    `ultra-scroll-up/down`, scroll around (both directions) in a big
    buffer with a large window, then `M-x elp-results`. The last column
    gives average time in seconds. Less than 0.003s (i.e. 3ms) is ideal,
    8ms is still perfectly usable, 15ms you'll feel a bit, 50ms will be
    very frustrating. `scroll-down` is always faster than `scroll-up`
    due to an asymmetry in Emacs' `vscroll` buffer.

[^3]: To try this yourself, `M-x elp-instrument-function` on both
    `ultra-scroll-up/down`, scroll around (both directions) in a big
    buffer with a large window, then `M-x elp-results`. The last column
    gives average time in seconds. Less than 0.003s (i.e. 3ms) is ideal,
    8ms is still perfectly usable, 15ms you'll feel a bit, 50ms will be
    very frustrating. `scroll-down` is always faster than `scroll-up`
    due to an asymmetry in Emacs' `vscroll` buffer.
