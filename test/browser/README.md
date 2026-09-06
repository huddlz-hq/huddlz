# Cover visual regression checks

Build the application assets with `mix assets.build`, then serve the repository
root with `python3 -m http.server 4013 --bind 127.0.0.1`.

Open `http://localhost:4013/test/browser/image_fallback.html` at 320px and a
desktop width. The fixture contains no JavaScript:

- Valid covers show the image; missing and failed covers show the fallback.
- Group covers crop to their frame; huddl detail covers contain the full image.
- Long group metadata stays within the hero and wraps without horizontal overflow.

Also inspect Discover, My groups, organizer, and detail views in the running app.
Changing a cover through LiveView should update the background without any
client-side image state. This fixture uses the application CSS and requires no
database or external images.
