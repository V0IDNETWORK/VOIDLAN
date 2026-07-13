This folder intentionally does not contain hand-written CMake project
files.

Generate the Linux runner scaffolding once with:

    flutter create --platforms=linux .

run from the project root (the folder containing pubspec.yaml). This
populates linux/ with CMakeLists.txt, runner/, and flutter/ correctly
for the Flutter SDK version installed on your machine, without
overwriting any of the lib/, pubspec.yaml, or android/ files already in
this project.

See ../README.md for the full build walkthrough.
