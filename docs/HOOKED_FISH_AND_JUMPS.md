# Hooked fish visibility and jumping

The active fish becomes visible within four metres of the landing point. `scripts/hooked_fish.gd` reuses the species model, normalized to its baseline centimetre length, horizontally oriented just below the current location's water level. Existing catch blend shapes run continuously at 11 Hz for a restrained swimming/twitching motion. One model is cached and replaced when the hooked species changes; it hides after loss, release or landing. The displayed landed catch retains its existing randomized final size.

The water shader keeps reflections and selectively transmits the shallow fish silhouette using reconstructed scene depth, avoiding a circular hole through the lake bed. This adds transparent rendering and depth-texture sampling to the water; headset performance and stereo appearance need physical-device validation. [Godot depth reconstruction reference](https://docs.godotengine.org/en/stable/tutorials/shaders/advanced_postprocessing.html).

## Leap and rapid tug

Rainbow trout and brown trout can jump with at least 55% stamina, beyond two metres from the landing point, at safe tension, and between other moves. Rainbow trout have a 60% chance at an eligible opportunity; brown trout 35%. Opportunities begin after seven seconds, with an 18-second cooldown and at most two attempts per cast. This is gameplay tuning, not a measured natural frequency. Hooked jumping behavior for both species is described by [New Zealand's Te Ara encyclopedia](https://teara.govt.nz/en/photograph/18278/jumping-rainbow-trout).

A 0.7-second warning precedes a 1.2-second lateral leap. The fish model follows the line's lateral displacement and a short vertical arc; an entry ripple and return splash signal the move. Other fight physics pause during the move so the jump cannot overlap a dive, run or ordinary hold. Existing tension is preserved.

**Counter: stop reeling, then make a rapid sideways tug against the leap while the fish is airborne.** VR detects at least 9 cm of movement within 0.15 seconds, with current speed at least 1 m/s, in a facing frame captured at the jump. Position is measured relative to the head in tracking-origin coordinates. A held pose or slow drift does not count. Desktop uses a fresh left/right arrow press; a pre-held arrow does not count.

A valid tug immediately subtracts 28 percentage points of stamina, once. Missing the airborne window, using the wrong direction or continuing to reel restores 25 points at splashdown. Both outcomes clamp stamina to 0–100% and provide three seconds of recovery. Ordinary directional counters still require their existing sustained hold.

## Checks

`tests/fish_jumps.gd` covers success/failure at 30/72/90 Hz, one-time stamina changes, wrong direction, continued reeling, held/slow versus rapid tracked movement, high-stamina species eligibility, naturally scheduled jumps, lifecycle cleanup, underwater metre scale, horizontal orientation and above-water emergence. Its `--capture` option renders underwater/jump previews. Existing fight-pattern, session, tackle, haptic, predator and scene-feedback suites cover regression behavior. Visual checks use desktop Vulkan; physical headset feel is untested.
