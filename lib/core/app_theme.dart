import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const radiusPanel = 20.0;
const radiusCard = 14.0;
const radiusField = 10.0;
const radiusSmall = 8.0;

class IosScrollBehavior extends MaterialScrollBehavior {
  const IosScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final accent = dark ? const Color(0xFFFF4F81) : const Color(0xFFE01E5A);
  final background = dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  final card = dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  final fill = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
  final separator = dark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6);
  final label = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  final secondary = dark ? const Color(0xFF98989F) : const Color(0xFF6C6C70);
  final tint = accent.withValues(alpha: dark ? 0.22 : 0.12);
  final green = dark ? const Color(0xFF30D158) : const Color(0xFF34C759);

  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: Color.alphaBlend(tint, card),
        onPrimaryContainer: accent,
        secondaryContainer: dark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFE9E9EE),
        onSecondaryContainer: label,
        surface: card,
        onSurface: label,
        surfaceContainerLowest: card,
        surfaceContainerLow: background,
        surfaceContainer: background,
        surfaceContainerHigh: fill,
        surfaceContainerHighest: fill,
        onSurfaceVariant: secondary,
        outline: separator,
        outlineVariant: separator,
        error: dark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30),
        errorContainer: dark
            ? const Color(0xFF3A1D1B)
            : const Color(0xFFFFE9E7),
        onErrorContainer: dark
            ? const Color(0xFFFF8F88)
            : const Color(0xFFB3261E),
        inverseSurface: dark
            ? const Color(0xFFE5E5EA)
            : const Color(0xFF2C2C2E),
        onInverseSurface: dark ? const Color(0xFF000000) : Colors.white,
      );

  OutlineInputBorder border(Color color, [double width = 0]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: width == 0
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  final fieldShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radiusCard),
  );
  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    dividerColor: separator,
    dividerTheme: DividerThemeData(
      color: separator,
      thickness: 0.5,
      space: 0.5,
    ),
    splashFactory: NoSplash.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: card.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: accent),
      actionsIconTheme: IconThemeData(color: accent),
      shape: Border(bottom: BorderSide(color: separator, width: 0.5)),
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: label,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCard),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCard),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: label,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusPanel)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(separator),
      enabledBorder: border(separator),
      focusedBorder: border(accent, 1.5),
      errorBorder: border(scheme.error, 1),
      focusedErrorBorder: border(scheme.error, 1.5),
      disabledBorder: border(separator),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: buttonShape,
        minimumSize: const Size(64, 48),
        textStyle: buttonText,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: buttonShape,
        minimumSize: const Size(64, 48),
        textStyle: buttonText,
        foregroundColor: accent,
        backgroundColor: tint,
        side: BorderSide.none,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: buttonShape,
        foregroundColor: accent,
        textStyle: buttonText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: accent),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: fill,
      selectedColor: tint,
      checkmarkColor: accent,
      labelStyle: TextStyle(color: label, fontSize: 14),
      secondaryLabelStyle: TextStyle(color: accent, fontSize: 14),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: tint,
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: IconThemeData(color: accent),
      selectedLabelTextStyle: TextStyle(color: accent, fontSize: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 62,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected) ? accent : secondary,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected) ? accent : secondary,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusCard),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      shape: fieldShape,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        shape: WidgetStatePropertyAll(fieldShape),
        backgroundColor: WidgetStatePropertyAll(card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      menuStyle: MenuStyle(
        shape: WidgetStatePropertyAll(fieldShape),
        backgroundColor: WidgetStatePropertyAll(card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: secondary, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accent : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? green
            : (dark ? const Color(0xFF39393D) : const Color(0xFFE5E5EA)),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: const WidgetStatePropertyAll(Colors.transparent),
      headingTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: secondary,
      ),
      dividerThickness: 0.5,
      dataTextStyle: TextStyle(fontSize: 15, color: label),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
      textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 13),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
  );
}
