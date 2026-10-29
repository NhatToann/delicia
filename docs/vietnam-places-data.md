# Vietnam place autocomplete data

The address picker bundles `assets/vietnam_places.json` (34 provinces/cities)
and `assets/vietnam_wards.json` (3,321 communes/wards) from Open Admin Data.
The records include current administrative names and representative coordinates,
so these suggestions continue to work offline. The dataset is licensed under
CC BY 4.0.

Attribution: Open Admin Data, [Vietnam Administrative Divisions](https://github.com/open-admin-data/vietnam-administrative-divisions),
CC BY 4.0. Data project: [openadmindata.org/vn](https://openadmindata.org/vn/).

This is an administrative-place index. It does not contain every street,
building number, or business. Photon/Nominatim remain responsible for detailed
address lookup; local suggestions are a fallback and use a commune/ward or
province representative coordinate when selected.
