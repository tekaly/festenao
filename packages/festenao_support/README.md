# Festenao support tools

```yaml
  festenao_support:
    git:
      url: https://github.com/tekaly/festenao
      path: packages/festenao_support
```

## Libraries

- `festenao_build_menu_flutter.dart`: build/deploy menus of the flutter apps.
- `festenao_firebase_menu.dart`: dev menu items on a firebase project through
  admin credentials: `firebaseFestenaoMenu` (app users, auth users, projects)
  and the generic `firebaseEntityMenu` for another tkcms entity database
  (calendelio plugs its calendars in).
