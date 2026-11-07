# SmartTube task runner. `just` lists recipes. Every recipe is safe to run from any cwd.
set shell := ["bash", "-euo", "pipefail", "-c"]

root      := justfile_directory()
workspace := root + "/SmartTube.xcworkspace"
core      := root + "/SmartTubeCore"
app       := root + "/SmartTubeApp"
derived   := env_var_or_default("SMARTTUBE_DERIVED_DATA", env_var("HOME") + "/DevTemp/smarttube/derived-data/xcode")
# Single source of truth for the target simulator. Override: `SMARTTUBE_TV_SIM="Apple TV" just test-ui`.
sim       := env_var_or_default("SMARTTUBE_TV_SIM", "Apple TV 4K (4th generation)")
scheme    := "Smart Tube"
destination := "platform=tvOS Simulator,name=" + sim
workers   := "3"   # 16 GB Mac Mini ceiling; 5 stalls clone boot (docs/running-tests.md)

default:
    @just --list

# --- quality gates ---------------------------------------------------------
format:
    xcrun swift-format format --in-place --recursive --configuration {{root}}/.swift-format {{core}} "{{app}}/Smart Tube" {{app}}/SmartTubeTests {{app}}/UITests

format-check:
    xcrun swift-format lint --strict --recursive --configuration {{root}}/.swift-format {{core}} "{{app}}/Smart Tube" {{app}}/SmartTubeTests {{app}}/UITests

lint:
    cd {{root}} && swiftlint lint --strict --baseline .swiftlint.baseline --config .swiftlint.yml

lint-baseline:
    cd {{root}} && swiftlint lint --write-baseline .swiftlint.baseline --config .swiftlint.yml || true

secrets-check:
    cd {{root}} && scripts/check-no-secrets.sh

doc-links:
    cd {{root}} && scripts/check-doc-links.sh

# --- build & test ------------------------------------------------------------
build:
    xcodebuild build -workspace {{workspace}} -scheme "{{scheme}}" -destination "{{destination}}" -derivedDataPath {{derived}} CODE_SIGNING_ALLOWED=NO -quiet

# Core tests run standalone; app tests are hosted by the app. Both need the tvOS simulator.
test-unit: test-core test-app

test-core:
    cd {{core}} && xcodebuild test -scheme SmartTubeCore -destination "{{destination}}" -derivedDataPath {{derived}}-package CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30

test-app:
    xcodebuild test -workspace {{workspace}} -scheme "{{scheme}}" -destination "{{destination}}" -derivedDataPath {{derived}} -only-testing:SmartTubeTests CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30

# filter: `just test-core-filter HLSManifestParserTests`
test-core-filter name:
    cd {{core}} && xcodebuild test -scheme SmartTubeCore -destination "{{destination}}" -derivedDataPath {{derived}}-package -only-testing:SmartTubeCoreTests/{{name}} CODE_SIGNING_ALLOWED=NO 2>&1 | tail -40

# filter: `just test-app-filter PlaybackEndAutoplayTests`
test-app-filter name:
    xcodebuild test -workspace {{workspace}} -scheme "{{scheme}}" -destination "{{destination}}" -derivedDataPath {{derived}} -only-testing:SmartTubeTests/{{name}} CODE_SIGNING_ALLOWED=NO 2>&1 | tail -40

# UI tests are disabled in SmartTube.xctestplan during the rework; enable them there first
test-ui:
    mkdir -p "$HOME/DevTemp/smarttube/logs"
    xcodebuild test -workspace {{workspace}} -scheme "{{scheme}}" -destination "{{destination}}" -derivedDataPath {{derived}} -parallel-testing-enabled YES -maximum-parallel-testing-workers {{workers}} -resultBundlePath $HOME/DevTemp/smarttube/logs/smarttube-ui.xcresult 2>&1 | tee $HOME/DevTemp/smarttube/logs/smarttube-ui.log | grep -E "Test Case|TEST SUCCEEDED|TEST FAILED|error:" | tail -60

# run one UI test: `just test-ui-one SmartTubeTVUITests/TVHomeFeedUITests/testName`
test-ui-one id:
    xcodebuild test -workspace {{workspace}} -scheme "{{scheme}}" -destination "{{destination}}" -derivedDataPath {{derived}} -only-testing:{{id}} 2>&1 | grep -E "Test Case|TEST SUCCEEDED|TEST FAILED|error:" | tail -20

ci: secrets-check doc-links format-check lint test-unit
    @echo "CI gate passed"

# regenerate the Unreleased section of CHANGELOG.md from Conventional Commits since the last tag
changelog:
    git-cliff --config {{root}}/cliff.toml --unreleased --prepend {{root}}/CHANGELOG.md

# --- metrics (ratchet, see docs/adr/0001) -------------------------------------
metrics:
    @echo "largest files:"; find {{core}}/Sources "{{app}}/Smart Tube" -name '*.swift' -exec wc -l {} + | sort -rn | head -11
    @echo "AGENTS.md bytes/lines:"; wc -c -l {{root}}/AGENTS.md
    @echo "a11y literals:"; grep -rho 'accessibilityIdentifier("' --include='*.swift' {{core}}/Sources "{{app}}/Smart Tube" | wc -l
    @echo "sleep( in UITests:"; grep -rhoE '\bsleep\(' {{root}}/SmartTubeApp/UITests | wc -l
    @echo "XCTSkip:"; grep -rho 'XCTSkip' {{root}}/SmartTubeApp/UITests | wc -l
    @echo ".shared reads in Views:"; grep -rho '\.shared\b' --include='*.swift' "{{app}}/Smart Tube/Views" | wc -l
    @echo "mirror tests:"; grep -rli 'mirror' {{core}}/Tests {{app}}/SmartTubeTests | wc -l
