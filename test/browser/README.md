# Browser regression checks

Build the production assets with `mix assets.build`, then serve the repository
root with `python3 -m http.server 4013 --bind 127.0.0.1`.

Open `http://localhost:4013/test/browser/image_fallback.html`. Every check should
report `PASS`, and `#results` should have `data-status="passed"`.

These checks use real browser image loads, the shared production fallback module,
and the built application CSS. They cover cached failures, images inserted after
initialization, LiveView patch preservation, failed and successful replacements,
all cover image classes, and
images outside the fallback contract. Long group metadata is also checked against
the hero frame, including locations without spaces. Run at 320px and a desktop
viewport to exercise both layouts. No database or external images are required.
