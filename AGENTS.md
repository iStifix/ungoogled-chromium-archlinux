# Repository Guidelines

## Project Structure & Module Organization
Automation, patch bundles, and helper scripts such as `smart-build.sh` and `fetch-libvpx-rtc.sh` live in the repository root for quick discovery. The Chromium checkout is contained in `src/chromium-140.0.7339.207/`, with GN and Ninja outputs emitted to `src/chromium-140.0.7339.207/out/<config>/`. Vendor toolchains (LLVM, libvpx, libaom, etc.) remain under `src/chromium-140.0.7339.207/third_party/`, and media-facing tests sit alongside sources in `media/gpu/vaapi/`.

## Build, Test, and Development Commands
Run `./smart-build.sh configure` to generate GN files using the repository defaults (arm64 target, VAAPI enabled, system sysroot disabled). Use `./smart-build.sh compile` for the standard incremental Chrome build, which wraps `ninja -C out/Release chrome`. Targeted media coverage comes from `ninja -C src/chromium-140.0.7339.207/out/Release media_unittests`, followed by `out/Release/media_unittests --gtest_filter=Vaapi*` to execute VAAPI-focused suites.

## Coding Style & Naming Conventions
Match Chromium style: GN files use two spaces, while C++ source and headers use four-space indentation with upstream brace placement. Keep targets lowercase with underscores (`third_party/libvpx:libvpxrc`), and name files in snake_case. Format C++ edits with `third_party/llvm-build/Release+Asserts/bin/clang-format` before sending patches, and prefer small, reviewable diffs.

## Testing Guidelines
Add new unit tests beside the code they exercise; for VAAPI layers, that usually means files such as `media/gpu/vaapi/*_unittest.cc` named `{ClassName}.{TestScenario}`. Run `media_unittests` and `content_unittests` after touching decode, encode, or acceleration logic, applying `--gtest_filter` to narrow focus when iterating quickly. Rerun flaky cases twice to confirm instability before filing issues, and document skipped tests in the change description.

## Commit & Pull Request Guidelines
Commit messages follow `<area>: brief change`, for example `vaapi: wire RTC rate control stubs`, with body text explaining what changed and why, plus `BUG=chromium:<id>` when relevant. Pull requests must summarize the change, cite validation output (e.g., `ninja -C out/Release chrome` or targeted test logs), and flag any third-party refreshes. Exclude generated artifacts such as `out/`, retain focused diffs, and link to dependent reviews when coordinating across repositories.

## Security & Configuration Tips
Keep credentials and API keys out of the tree; prefer environment variables or GN args files ignored by Git. When experimenting with GN args, stage them in `out/Release/args.gn` but avoid checking them in—capture noteworthy toggles in the change description instead. Review new patches for codec-level regressions on hardware-accelerated paths before landing.
