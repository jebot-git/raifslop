# Course authoring inputs

OpenStreetMap XML extracts are archived under `raw/`, including the original Spyglass/Pebble extracts from the Golf Minus authoring project and the complete new Cypress/Poppy extents. © OpenStreetMap contributors, ODbL: https://www.openstreetmap.org/copyright . Derived databases are offered under the same license.

`*_elevation.json` contain ten-by-ten regional Copernicus GLO-90 elevation samples obtained through Open-Meteo. New files retain the exact request URL and retrieval date. © European Union / Copernicus programme; Copernicus / Open-Meteo. https://open-meteo.com/en/docs/elevation-api

`tools/fetch_course_inputs.py` retrieves the new raw inputs. `tools/build_reference_courses.py` regenerates the two additional courses offline with numpy, Pillow and shapely, then applies `tools/build_course_lanes.py`. The latter can also run independently on all four mapped courses. It retains the original mapped routes/outlines, adds continuous fairway connections from all three tees to every pin, routes around sand/water, and clears tree canopies from those connections. Geometry uses a local WGS84 projection, metres, +X east and -Z north; terrain resolution is 2 m and lie resolution 1 m. Greens, bunker depth, vegetation, connected play lanes and clubhouse placement are gameplay approximations.

Cypress Point is the coastal course; Poppy Hills provides the forest course. Both have complete 18-hole OSM routes, unlike the partial coverage in the original archive. Their geographic boundaries, fairways, tees, greens, bunkers and water remain mapped data; no official map artwork is used as a game texture.
