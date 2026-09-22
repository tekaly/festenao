# Festenao explorers demo

Everything the explorers of `festenao_common_flutter` reach, on content built
at startup **in memory**: nothing is written to the disk, and modifications are
lost on restart — which is what makes it safe to edit anything in it.

```sh
flutter run -d linux      # or -d chrome
```

The platform runners are not in the repository — `linux/` and `web/` are
gitignored here, as they are for the other examples — so a fresh clone
regenerates them first:

```sh
flutter create --project-name festenao_dashboard_app_demo \
    --platforms=linux,web --org com.tekaly .
```

## What the menu offers

| Entry | On |
|---|---|
| Firestore explorer | an in-memory firestore: three collections, a sub collection, and a document holding every firestore type |
| File system explorer | an in-memory `fs_shim` file system: a json, a yaml, a text and a binary document, a sub directory, and the two databases below |
| Sdb explorer | the sdb databases **found** in that file system, not a path typed by hand |
| Sembast explorer | the sembast ones, told apart from the sdb ones by what each file holds |
| Every database | both kinds together |
| Edit an object in memory | the editor on a value, answering what it became |

Everything is read write, `Sdb explorer` and `Sembast explorer` going through
`listFileSystemDatabases`, which walks the tree and opens each candidate to
tell what it is — so the list is what can really be browsed rather than what is
merely named `.db`.

## What it is built from

- `lib/src/demo_data.dart` builds it all, reusing the shared demo content
  (`demoJsonContent`, `fillDemoSembastDatabase`, `demoSdbDatabaseSchema`,
  `fillDemoFirestore`…), so the demo and the `+` menu of the file system
  explorer show the same thing.
- `lib/src/demo_home_page.dart` is the menu.

See `packages/festenao_common/doc/` for what each explorer does.
