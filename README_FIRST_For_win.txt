This folder intentionally does not contain hand-written CMake/Visual
Studio project files.

Windows (and Linux) runner projects are generated, machine-specific
build scaffolding — normally produced by the Flutter SDK itself, not
authored by hand. Generate it once with:

    flutter create --platforms=windows .

run from the project root (the folder containing pubspec.yaml). This
populates windows/ with CMakeLists.txt, runner/, and flutter/ correctly
for the Flutter SDK version installed on your machine, without
overwriting any of the lib/, pubspec.yaml, or android/ files already in
this project.

See ../README.md for the full build walkthrough.
