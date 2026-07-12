import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide theme mode. Defaults to dark to match the cyber visual
/// identity; the About/Settings area exposes a toggle that flips this.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
