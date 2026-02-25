import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps widget in MaterialApp for widget tests.
/// Optionally set [size] to control MediaQuery.size for responsive breakpoints.
Widget createTestApp(Widget child, {Size? size}) {
  if (size != null) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    );
  }
  return MaterialApp(home: Scaffold(body: child));
}

/// Wraps widget in MaterialApp + ProviderScope for ConsumerWidget tests.
Widget createTestAppWithProviders(
  Widget child, {
  List<Override> overrides = const [],
  Size? size,
}) {
  if (size != null) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(body: child),
        ),
      ),
    );
  }
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}
