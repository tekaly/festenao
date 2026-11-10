/// The older festenao theme: `themeData1` (dark) and `themeDataLight1`, seeded
/// from one colour, their Poppins variants, and the font loader. New code
/// uses the presets of `package:festenao_theme/design.dart`.
library;

export 'fonts.dart'
    show
        loadFestenaoFonts,
        loadFestenaoFont,
        festenaoFonts,
        FestenaoFontFamily,
        poppinsFont,
        poppinsExtraBoldFont,
        jetBrainsMonoFont;
export 'fonts/jetbrains_mono/jetbrains_mono_font.dart'
    show addJetBrainsMonoLicense;
export 'fonts/poppins/poppins_font.dart' show addPoppinsLicense;
export 'src/theme1.dart'
    show
        poppinsThemeData1,
        poppinsThemeDataLight1,
        themeData1,
        themeDataLight1,
        festenaoPoppinsFontFamily,
        festenaoMonospaceFontFamily,
        colorFestenaoFormBlueSelected;
