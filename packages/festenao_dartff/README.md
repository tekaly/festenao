# dart firebase functions

The festenao cloud functions in Dart (admin sdk runtime, `dart3`):
`functions/bin/server.dart` registers, for a dev and a prod `FfApp`:

| Function (dev / prod) | What |
|---|---|
| `commanddartv2dev` / `commanddartv2prod` | the api, http |
| `callcommanddartv2dev` / `callcommanddartv2prod` | the api, callable (authenticated) |
| `ampdev` / `amp` | the amp page |
| `cmsdev` / `cms` | the cms sites of the projects |
| `cmsdemo` (flavor free) | the hard coded demo site of `festenao_demo` |

## Cms sites

`cms[dev]` serves the published pages of the synced content database
`app/<app>/project/<projectId>/data/<dataId>` of a project:

```
https://<hosting>/cms/<projectId>/<dataId>/             index
https://<hosting>/cms/<projectId>/<dataId>/page/<slug>  a page
https://<hosting>/cms/<projectId>/<dataId>/sitemap.xml
https://<hosting>/cms/<projectId>/<dataId>/robots.txt
https://<hosting>/cmsdemo/                              the demo site
```

The app hosting (same firebase project as the functions) rewrites them to
the function of its flavor, before its `**` rewrite:

```json
"redirects": [
  { "source": "/cmsdemo", "destination": "/cmsdemo/", "type": 301 }
],
"rewrites": [
  { "source": "/cms/**", "function": { "functionId": "cmsdev", "region": "europe-west1" } },
  { "source": "/cmsdemo/**", "function": { "functionId": "cmsdemo", "region": "europe-west1" } },
  { "source": "**", "destination": "/index.html" }
]
```

The links of a site follow the url the visitor typed (the forwarded host of
the hosting), so the same function also answers at its own url and on a
local runner (`http://localhost:8040/cmsdev/<projectId>/<dataId>/`). An app
customizes its sites with the hooks of `FestenaoServerApp` (`cmsSiteOf`,
`cmsSiteHandler`, `cmsContentSdbOptions`...).

## Build, test

```sh
dart run tool/compile_dart_function.dart   # functions/bin/server (linux x64)
dart test test/cms_function_test.dart      # cms functions, in memory
dart test test/cms_emulator_test.dart      # cms functions, on the emulator
dart test test/emulator_test.dart          # the api, on the emulator
```

`functions/functions.yaml` is generated (`dart run build_runner build` in
`functions/`, or by the firebase cli on deploy).
