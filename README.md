# ultra-scroll: scroll emacs like lightning ⚡🖱️⚡

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
> If you scroll buffers with tall images visible, this is also a good
> reason to give `ultra-scroll` a try.

## Compatibility, Installation, and Usage

`ultra-scroll` should work across all systems that provide pixel
scrolling information; see the `PIXEL-DELTA` field of `wheel-up/down`
events.

### Installation

Not yet in a package archive. For Emacs 29.1 and later, use
`package-vc-install`. In the `*scratch*` buffer, enter

``` commonlisp
(package-vc-install '(ultra-scroll :vc-backend Git :url  "https://github.com/jdtsmith/ultra-scroll"))
```

move to the final paren, and `C-x C-e`. Installation is then simple:

``` commonlisp
(use-package ultra-scroll
  ;:load-path "~/code/emacs/ultra-scroll" ; if you git clone'd instead of package-vc-install
  :init
  (setq scroll-conservatively 101 ; important!
        scroll-margin 0) 
  :config
  (ultra-scroll-mode 1))
```

### Usage

Just start scrolling :).

> [!TIP]
> For best performance, use a build with native-compilation (see
> [Speed](#Speed)).

## Configuration

There is little to no configuration. If desired for use with dumb mice
on `emacs-mac`, the variable `ultra-scroll-mac-multiplier` can be set to
a number smaller or larger than `1.0` to decrease/increase mouse-wheel
scrolling speed. Note that many fancier wheeled mice have drivers that
*simulate* track-pads, so this variable will have no effect on them. For
these, and for track-pads generally, scrolling speed should be
configured in system settings.

To reduce the likelihood of garbage collection during scroll, which can
introduce slight pauses, the value of `gc-cons-percentage` is
temporarily increased, and reset during idle time. The defaults should
work well for most situations, but if necessary, can be configured using
`ultra-scroll-gc-percentage` and `ultra-scroll-gc-idle-time`.

## Related packages and functionality

emacs-mac's own builtin `mac-mwheel-scroll`  
This venerable code was introduced with
[emacs-mac](https://bitbucket.org/mituharu/emacs-mac/) more than a
decade ago, and was the first to provide smooth scrolling in emacs.

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
Includes smooth scrolling based on sublime editor.

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
scrolling events a second. *But track-pad scroll events are arriving
every 15ms or less*! The code just couldn't keep up. Hence the molasses.

I also wanted to be able to scroll through image-rich documents without
worrying about jumpy/loopy scrolling behavior. And my extra dumb mouse
didn't work well either: small scrolls did nothing: you'd have scroll
pretty aggressively to get any movement at all.

How hard could it be to fix this? And the adventure began…

### Why was this initially for emacs-mac only?

This packaged used to be called `ultra-scroll-mac`. The `emacs-mac` port
of emacs exposes pixel-level scrolling event stream of Mac track-pads
(and other fancy mice) in a distinct way, which is not supported by
`pixel-scroll-precision-mode`. And unfortunately the default
smooth-scrolling library included in `emacs-mac` is quite low
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
*feature-complete track-pad driver* in elisp for older mice which do not
supply pixel scroll information. This comes complete with elisp-based
scroll interpolation, a timer-based *momentum* phase, etc.

### Why are there so many smooth scrolling modes? Why is this so hard? It's just *scrolling/*…

Emacs was designed long before mice were common, not to mention modern
high-resolution track-pads which send rapid micro-updates ("move up one
pixel!") more than 60 times per second. Unlike other programs, Emacs
insists on keeping the cursor (point) visible at all times. Deep in its
re-display code, Emacs tracks where point is, and works diligently to
ensure it never falls outside the visible window. It does this not by
moving point (that's the user's job), but by moving the *window*
(visible range of lines) surrounding point.

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
  into play only on re-display (after your event handler returns).
- Virtual Scroll:
  - `vscroll` – a virtual rendered scrolling window hiding *below* the
    current window – is key to smooth scrolling, and altering `vscroll`
    to move the view-port is incredibly fast.
  - There is plenty of `vscroll` room available, including the entirety
    of any tall lines (as for displayed images) in view.
  - `vscroll` can sometimes place the point off the visible window (I
    know, sacrilege), but more often triggers rec-entering.
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
  tab-bar, but *not* the tab-bar-mode bar.
- Jumbo lines (lines taller than the window's height):
  - Scrolling towards buffer end:
    - When scrolling with jumbo lines towards the buffer's end (with
      `vscroll`), simply keep *point on the jumbo line* until it fully
      disappears from view. As a special case, Emacs will not re-center
      when this happens.
    - This is *not* true for lines that are shorter than the usable
      window height. In this case, you must *avoid* placing point on any
      line which falls partially out of view.
  - Scrolling towards buffer start:
    - When scrolling up past jumbo lines towards the buffer's start
      using `set-window-start` (lines of content move down), you must
      keep point on the jumbo, but *only until it clears the top of the
      window area* (even by one pixel).
    - After this, you must move the point to the line above it (and had
      better insist that `scroll-conservatively>0` to prevent
      re-centering).
    - In some cases (depending on truncation/visual-line-mode/etc.),
      this movement must occur from a position beyond the first full
      height object (which may not be at the line's start). E.g. one
      before the visual line end.
- `pos-visible-in-window` doesn't always give correct results near the
  window boundaries. Better to use the first line at the window's top or
  directly identify the final line (both via `pos-at-x-y`) and adjust
  from there.
- Display bugs
  - There are
    [display](https://debbugs.gnu.org/cgi/bugreport.cgi?bug=67533)
    [bugs](https://debbugs.gnu.org/cgi/bugreport.cgi?bug=67604) with
    inline images that cause them to misreport pixel measurements and
    positions sometimes.
  - These lead to slightly staccato scrolling in such buffers and
    `height=0` gets erroneously reported, so can't be used to find
    beginning of buffer.
  - **Update:** Two display bugs have been fixed in master as of Dec,
    2023, so scrolling with lots of inline images will soon be even
    smoother. [One
    bug](https://debbugs.gnu.org/cgi/bugreport.cgi?bug=67604) related to
    motion skipping visual-wrapped lines with images at line start
    remains.

So all in all, it's quite complicated to get something that works as
you'd hope. The cutting room floor is littered with literally dozens of
almost-but-not-quite-working versions of `ultra-scroll`. I'm sure there
are many more corner cases, but the current design gets most things
right in my usage.

## Speed

Some observations about the speed of `ultra-scroll`. I used `ELP` to
measure the average call duration of individual scroll functions
(`ultra-scroll-up/down`) with various buffer and window sizes. Take
aways:

1.  You can definitely start feeling it when scroll commands take more
    than 15ms. These need to leave time for other emacs commands that
    occur when new content is brought into view (font-lock), so faster
    is better.
2.  Building `--with-native-comp` is *essential* for ultra-smooth
    scrolling. It increases the speed of each individual scroll command
    by **\>3x**, which is important since these commands are called so
    frequently.
3.  On the same build (NS, v29.4, with native-comp), `ultra-scroll` is
    about **40% faster** than `pixel-scroll-precision-mode`. Except on
    slower machines, or in very heavy buffers and/or on large window
    sizes, this shouldn't be too noticeable.
4.  On the same system (an M2 mac), `ultra-scroll` on `emacs-mac` is
    10-15% faster than on NS builds like `emacs-plus`. Very likely not
    noticeable.

[^1]: Formerly `ultra-scroll-mac`.