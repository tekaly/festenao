# Festenao support tools

```yaml
  festenao_support:
    git:
      url: https://github.com/tekaly/festenao
      path: packages/festenao_support
```

## Commands

- `festenao_service_account`: stores the service account of the admin builds
  and tools where they look for it, a file of
  `~/.config/tekartik/festenao/service_accounts` and/or the
  `FESTENAO_SERVICE_ACCOUNT` variable of the ds env user file:

  ```sh
  dart run festenao_support:festenao_service_account write ~/Downloads/sa.json --ds-env
  dart run festenao_support:festenao_service_account list
  ```

  See `doc/admin_service_account.md` of the festenao repository.

## Libraries

- `festenao_build_menu_flutter.dart`: build/deploy menus of the flutter apps.
- `festenao_firebase_menu.dart`: dev menu items on a firebase project through
  admin credentials: `firebaseFestenaoMenu` (app users, auth users, projects)
  and the generic `firebaseEntityMenu` for another tkcms entity database
  (calendelio plugs its calendars in); `menuFestenaoFbAppProjectContent` acts
  on a `FestenaoFbAppProject` at three levels — the auth users, the app
  (`app/<appId>`, where an app admin is granted) and an app project
  (`app/<appId>/project/<projectId>` and its per user access) — finding and
  creating users, granting and revoking access.
- `festenao_firebase_admin_sdk.dart`: firebase initialisation through the admin
  sdk, with a service account map or the ambient credentials.
