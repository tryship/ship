# Toolchain Detection Matrix

Complete Phase 1.3 detection rules for supported language toolchains.

Detection order:
- Scan repository config files, manifests, lockfiles, and conventional test/layout markers first.
- Verify the selected tool is executable before marking it `ready`.
- Use `missing` when no configured tool exists for a category.
- Use `broken` when config exists but the referenced tool is unavailable or clearly unusable.
- Only fall back to the default tool when the repo has not already chosen one.

## Python

**Linter**
- Check: `ruff.toml`, `pyproject.toml[tool.ruff]`, `.flake8`, `setup.cfg[flake8]`, `.pylintrc`, `pyproject.toml[tool.pylint]`
- Verify: `ruff --version`, `flake8 --version`, `pylint --version`
- Default (if missing): `ruff`
- Install: `uv add --dev ruff` or `pip install ruff`

**Formatter**
- Check: `ruff.toml` formatter settings, `pyproject.toml[tool.ruff]`, `.style.yapf`, `pyproject.toml[tool.black]`, `setup.cfg[yapf]`
- Verify: `ruff format --help`, `black --version`, `yapf --version`
- Default (if missing): `ruff format`
- Install: `uv add --dev ruff` or `pip install ruff`

**Type Checker**
- Check: `pyrightconfig.json`, `pyproject.toml[tool.pyright]`, `mypy.ini`, `.mypy.ini`, `pyproject.toml[tool.mypy]`
- Verify: `pyright --version`, `mypy --version`
- Default (if missing): `pyright`
- Install: `uv add --dev pyright` or `pip install pyright`

**Test Runner**
- Check: `pyproject.toml[tool.pytest]`, `pytest.ini`, `setup.cfg[tool:pytest]`, `tests/`, `test_*.py`
- Verify: `pytest --co -q`
- Default (if missing): `pytest`
- Install: `uv add --dev pytest pytest-cov`

## TypeScript / JavaScript

**Linter**
- Check: `eslint.config.js`, `eslint.config.mjs`, `eslint.config.cjs`, `eslint.config.ts`, `.eslintrc`, `.eslintrc.js`, `.eslintrc.cjs`, `.eslintrc.json`, `.eslintrc.yml`, `.eslintrc.yaml`, `biome.json`, `biome.jsonc`
- Verify: `eslint --version`, `biome --version`
- Default (if missing): `eslint`
- Install: `npm install -D eslint`

**Formatter**
- Check: `.prettierrc`, `.prettierrc.js`, `.prettierrc.cjs`, `.prettierrc.json`, `.prettierrc.yml`, `.prettierrc.yaml`, `package.json[prettier]`, `biome.json`, `dprint.json`
- Verify: `prettier --version`, `biome --version`, `dprint --version`
- Default (if missing): `prettier`
- Install: `npm install -D prettier`

**Type Checker**
- Check: `tsconfig.json` and whether `compilerOptions.strict` is `true`
- Verify: `tsc --noEmit --pretty false`
- Default (if missing): `tsc strict`
- Install: `npm install -D typescript`

**Test Runner**
- Check: `vitest.config.js`, `vitest.config.mjs`, `vitest.config.cjs`, `vitest.config.ts`, `vite.config.js` with `test`, `vite.config.mjs` with `test`, `vite.config.cjs` with `test`, `vite.config.ts` with `test`, `jest.config.js`, `jest.config.mjs`, `jest.config.cjs`, `jest.config.ts`, `package.json[jest]`, `*.test.*`, `*.spec.*`
- Verify: `vitest --version`, `jest --version`
- Default (if missing): `vitest`
- Install: `npm install -D vitest`

## Go

**Linter**
- Check: `.golangci.yml`, `.golangci.yaml`
- Verify: `golangci-lint --version`
- Default (if missing): `golangci-lint`
- Install: `go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest`

**Formatter**
- Check: built-in `gofmt`
- Verify: `gofmt -h`
- Default (if missing): `gofmt`
- Install: None, built into Go toolchain

**Test Runner**
- Check: built-in `go test`, `_test.go`
- Verify: `go test ./...`
- Default (if missing): `go test`
- Install: None, built into Go toolchain

## Rust

**Linter**
- Check: `Cargo.toml`, optional `clippy.toml`
- Verify: `cargo clippy --version`
- Default (if missing): `clippy`
- Install: None, built into Rust toolchain

**Formatter**
- Check: `Cargo.toml`, optional `rustfmt.toml`, `.rustfmt.toml`
- Verify: `rustfmt --version`
- Default (if missing): `rustfmt`
- Install: None, built into Rust toolchain

**Test Runner**
- Check: built-in `cargo test`, `tests/`, `#[cfg(test)]`
- Verify: `cargo test -- --help`
- Default (if missing): `cargo test`
- Install: None, built into Rust toolchain

## Java

**Linter**
- Check: `checkstyle.xml`, `checkstyle/`, SpotBugs config, `pom.xml` Checkstyle plugin, `build.gradle*` Checkstyle or SpotBugs plugins
- Verify: `checkstyle --version`, `spotbugs -version`
- Default (if missing): `checkstyle`
- Install: `mvn com.puppycrawl.tools:checkstyle:checkstyle` or add the Checkstyle plugin to Maven/Gradle build

**Formatter**
- Check: `google-java-format` config or wrapper, `.editorconfig` with Java formatting rules
- Verify: `google-java-format --version`
- Default (if missing): `google-java-format`
- Install: `brew install google-java-format` or add `google-java-format` to project tooling

**Test Runner**
- Check: `src/test/`, JUnit dependencies, Surefire config in `pom.xml`, Gradle `test` task
- Verify: `mvn test -q` or `gradle test`
- Default (if missing): matches build tool
- Install: add JUnit and use the existing Maven or Gradle test task

## C#

**Linter**
- Check: SDK-style project analyzers, `Directory.Build.props`, `.editorconfig`, analyzer package references
- Verify: `dotnet build`
- Default (if missing): `dotnet analyzers`
- Install: None, built into .NET SDK

**Formatter**
- Check: `.editorconfig`, `dotnet format` availability
- Verify: `dotnet format --version`
- Default (if missing): `dotnet format`
- Install: None, built into .NET SDK

**Test Runner**
- Check: `*.csproj` test SDK references, `*.sln`, `tests/`
- Verify: `dotnet test --list-tests`
- Default (if missing): `dotnet test`
- Install: None, built into .NET SDK

## PHP

**Linter**
- Check: `phpstan.neon`, `phpstan.neon.dist`, `phpcs.xml`, `phpcs.xml.dist`
- Verify: `phpstan --version`, `phpcs --version`
- Default (if missing): `phpstan`
- Install: `composer require --dev phpstan/phpstan`

**Formatter**
- Check: `.php-cs-fixer.php`, `.php-cs-fixer.dist.php`
- Verify: `php-cs-fixer --version`
- Default (if missing): `php-cs-fixer`
- Install: `composer require --dev friendsofphp/php-cs-fixer`

**Test Runner**
- Check: `phpunit.xml`, `phpunit.xml.dist`
- Verify: `phpunit --version`
- Default (if missing): `phpunit`
- Install: `composer require --dev phpunit/phpunit`

## Ruby

**Linter**
- Check: `.rubocop.yml`
- Verify: `rubocop --version`
- Default (if missing): `rubocop`
- Install: `bundle add rubocop --group development`

**Formatter**
- Check: `.rubocop.yml` with formatting cops or auto-correct usage
- Verify: `rubocop --version`
- Default (if missing): `rubocop`
- Install: `bundle add rubocop --group development`

**Type Checker**
- Check: `sorbet/`, `.srb/`
- Verify: `srb version`
- Default (if missing): none, optional and should be skipped if absent
- Install: `bundle add sorbet --group development`

**Test Runner**
- Check: `spec/` for RSpec, `test/` for Minitest, `.rspec`
- Verify: `rspec --version`, `ruby -Itest -e "require 'minitest/autorun'"`
- Default (if missing): `minitest`
- Install: `bundle add rspec --group test` or use bundled `minitest`

## Kotlin

**Linter**
- Check: `.editorconfig` with `ktlint`, `detekt.yml`, `detekt-config.yml`
- Verify: `ktlint --version`, `detekt --version`
- Default (if missing): `ktlint`
- Install: add the `ktlint` Gradle plugin

**Formatter**
- Check: `.editorconfig` with `ktlint` formatting rules
- Verify: `ktlint --version`
- Default (if missing): `ktlint`
- Install: add the `ktlint` Gradle plugin

**Test Runner**
- Check: Gradle `test` task, `src/test/`, JUnit dependencies
- Verify: `gradle test --dry-run`
- Default (if missing): `gradle test`
- Install: None, provided by Gradle/JUnit project setup

## Swift

**Linter**
- Check: `.swiftlint.yml`
- Verify: `swiftlint --version`
- Default (if missing): `swiftlint`
- Install: `brew install swiftlint`

**Formatter**
- Check: `.swiftformat`
- Verify: `swiftformat --version`
- Default (if missing): `swiftformat`
- Install: `brew install swiftformat`

**Test Runner**
- Check: `Package.swift`, XCTest targets, `Tests/`
- Verify: `swift test --list-tests`
- Default (if missing): `swift test`
- Install: None, built into Swift Package Manager and XCTest

## Dart / Flutter

**Linter**
- Check: `analysis_options.yaml`
- Verify: `dart analyze`, `flutter analyze`
- Default (if missing): `dart analyze`
- Install: None, built into Dart and Flutter toolchains

**Formatter**
- Check: built-in `dart format`
- Verify: `dart format --help`
- Default (if missing): `dart format`
- Install: None, built into Dart and Flutter toolchains

**Test Runner**
- Check: `test/`, `pubspec.yaml`, Flutter package markers
- Verify: `dart test --list`, `flutter test --list`
- Default (if missing): `dart test`, or `flutter test` when Flutter is detected
- Install: None, built into Dart and Flutter toolchains

## Elixir

**Linter**
- Check: `.credo.exs`
- Verify: `mix credo --version`
- Default (if missing): `credo`
- Install: add `{:credo, "~> 1.7", only: [:dev, :test]}` to `mix.exs` deps

**Formatter**
- Check: built-in `mix format`, optional `.formatter.exs`
- Verify: `mix format --check-formatted`
- Default (if missing): `mix format`
- Install: None, built into Mix

**Type Checker**
- Check: `mix.exs` deps for `dialyxir`
- Verify: `mix dialyzer --version`
- Default (if missing): none, optional and should be skipped if absent
- Install: add `{:dialyxir, "~> 1.4", only: [:dev], runtime: false}` to `mix.exs` deps

**Test Runner**
- Check: built-in ExUnit, `test/`
- Verify: `mix test --list`
- Default (if missing): `mix test`
- Install: None, built into ExUnit and Mix

## Scala

**Linter**
- Check: `.scalafix.conf`, `wartremover` in `build.sbt`
- Verify: `sbt scalafix --help`, `sbt wartremoverWarnings`
- Default (if missing): `scalafix`
- Install: add `sbt-scalafix` to `project/plugins.sbt`

**Formatter**
- Check: `.scalafmt.conf`
- Verify: `sbt scalafmt --help`
- Default (if missing): `scalafmt`
- Install: add `sbt-scalafmt` to `project/plugins.sbt`

**Test Runner**
- Check: ScalaTest or Specs2 in `build.sbt`, `src/test/`
- Verify: `sbt test`
- Default (if missing): `sbt test`
- Install: add ScalaTest or Specs2 dependency to the existing SBT build

## C / C++

**Linter**
- Check: `.clang-tidy`
- Verify: `clang-tidy --version`
- Default (if missing): `clang-tidy`
- Install: comes with Clang/LLVM

**Formatter**
- Check: `.clang-format`
- Verify: `clang-format --version`
- Default (if missing): `clang-format`
- Install: comes with Clang/LLVM

**Test Runner**
- Check: `CMakeLists.txt` with `enable_testing()`, GoogleTest or Catch2 references
- Verify: `ctest --version`
- Default (if missing): `ctest`
- Install: comes with CMake
