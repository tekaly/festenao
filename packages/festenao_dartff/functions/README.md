# festenao_dartff_functions

The deployed entry point of the festenao Dart cloud functions (runtime
`dart3`, the `functions` source of `../firebase.json`). `bin/server.dart`
registers, in `europe-west1`, for a dev and a prod `FfApp` of
[`festenao_dartff`](../README.md):

| Function | What |
|---|---|
| `commanddartv2dev`, `commanddartv2prod` | the api over http |
| `callcommanddartv2dev`, `callcommanddartv2prod` | the api as a callable |
| `ampdev`, `amp` | the amp page |
| `cmsdev`, `cms` | the cms sites of the projects (hosting rewrite `/cms/`) |
| `cmsdemo` | the hard coded demo site (`/cmsdemo/`) |

Both flavors are deployed to the project the deploy targets; each server
works on the app of its own flavor. The raw firestore doc api is served only
under the emulator (`isFunctionsEmulator`).

The logic lives in `festenao_dartff` (its tests run it in memory); this
package only wires it. `functions.yaml` is generated from `bin/server.dart`
(`dart run build_runner build` here, or by the firebase cli on deploy):
keep the function names constants.
