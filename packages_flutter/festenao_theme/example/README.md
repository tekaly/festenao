# festenao_theme_example

The festenao themes gallery: every preset of `package:festenao_theme/design.dart`,
light and dark, on sample screens (a festival day, the access of a project,
the kit), with the phone, tablet and desk layouts.

```bash
flutter create --platforms=linux,web .   # once: the platform folders are not tracked
flutter run -d linux                     # or -d chrome
flutter test                             # every page at three sizes
flutter test tool/screenshot_test.dart   # every preset into .local/themes
python3 -I tool/contact_sheet.py         # side by side sheets + index.html
```
