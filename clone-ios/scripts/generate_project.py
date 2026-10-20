#!/usr/bin/env python3
"""Generate a hand-authored Xcode project for the app + keyboard extension."""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "WeTypeClone.xcodeproj"
PBX = PROJECT / "project.pbxproj"

APP_FILES = sorted((ROOT / "WeTypeClone" / "App").glob("*.swift"))
SHARED_FILES = sorted((ROOT / "Shared").glob("*.swift"))
KB_FILES = sorted((ROOT / "Keyboard").glob("*.swift"))
TEST_FILES = sorted((ROOT / "WeTypeCloneUITests").glob("*.swift"))
RESOURCES = [
    ROOT / "WeTypeClone" / "Resources" / name
    for name in ("lexicon.sqlite", "emoji.json", "phrases.json", "fuzzy_pinyin.json", "double_pinyin.json")
]

_ids = iter(range(1, 100000))


def oid() -> str:
    return f"AA{next(_ids):022X}"


class Builder:
    def __init__(self) -> None:
        self.objects: dict[str, str] = {}
        self.file_refs: dict[Path, str] = {}
        self.build_files: dict[tuple[str, Path], str] = {}

    def add(self, oid_value: str, body: str) -> str:
        self.objects[oid_value] = body
        return oid_value

    def file_ref(self, path: Path, file_type: str, name: str | None = None, source_tree: str = "<group>") -> str:
        if path in self.file_refs:
            return self.file_refs[path]
        value = oid()
        display = name or path.name
        self.add(value, f"{{isa = PBXFileReference; lastKnownFileType = {file_type}; path = \"{display}\"; sourceTree = \"{source_tree}\"; }}")
        self.file_refs[path] = value
        return value

    def build_file(self, target: str, path: Path) -> str:
        key = (target, path)
        if key in self.build_files:
            return self.build_files[key]
        value = oid()
        ref = self.file_refs[path]
        self.add(value, f"{{isa = PBXBuildFile; fileRef = {ref}; }}")
        self.build_files[key] = value
        return value


b = Builder()

# Products / frameworks
app_product = b.add(oid(), "{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = WeTypeClone.app; sourceTree = BUILT_PRODUCTS_DIR; }")
kb_product = b.add(oid(), "{isa = PBXFileReference; explicitFileType = \"wrapper.app-extension\"; includeInIndex = 0; path = WeTypeKeyboard.appex; sourceTree = BUILT_PRODUCTS_DIR; }")
test_product = b.add(oid(), "{isa = PBXFileReference; explicitFileType = \"wrapper.cfbundle\"; includeInIndex = 0; path = WeTypeCloneUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }")
sqlite_ref = b.add(oid(), "{isa = PBXFileReference; lastKnownFileType = \"sourcecode.text-based-dylib\"; name = libsqlite3.tbd; path = usr/lib/libsqlite3.tbd; sourceTree = SDKROOT; }")
sqlite_build_app = b.add(oid(), f"{{isa = PBXBuildFile; fileRef = {sqlite_ref}; }}")
sqlite_build_kb = b.add(oid(), f"{{isa = PBXBuildFile; fileRef = {sqlite_ref}; }}")
xctest_ref = b.add(oid(), "{isa = PBXFileReference; lastKnownFileType = \"wrapper.framework\"; name = XCTest.framework; path = System/Library/Frameworks/XCTest.framework; sourceTree = SDKROOT; }")
xctest_build = b.add(oid(), f"{{isa = PBXBuildFile; fileRef = {xctest_ref}; }}")

# File refs
app_group_files = []
for path in APP_FILES:
    b.file_ref(path, "sourcecode.swift")
    app_group_files.append(path)
resource_refs = []
for path in RESOURCES:
    b.file_ref(path, "text.json" if path.suffix == ".json" else "file")
    resource_refs.append(path)
assets_ref = b.file_ref(ROOT / "WeTypeClone" / "Assets.xcassets", "folder.assetcatalog")
info_ref = b.file_ref(ROOT / "WeTypeClone" / "Info.plist", "text.plist.xml")
ent_ref = b.file_ref(ROOT / "WeTypeClone" / "WeTypeClone.entitlements", "text.plist.entitlements")
kb_info_ref = b.file_ref(ROOT / "Keyboard" / "Info.plist", "text.plist.xml")
kb_ent_ref = b.file_ref(ROOT / "Keyboard" / "Keyboard.entitlements", "text.plist.entitlements")
shared_refs = [b.file_ref(p, "sourcecode.swift") for p in SHARED_FILES]
kb_refs = [b.file_ref(p, "sourcecode.swift") for p in KB_FILES]
test_refs = [b.file_ref(p, "sourcecode.swift") for p in TEST_FILES]

# Build files
app_source_builds = [b.build_file("app", p) for p in APP_FILES + SHARED_FILES]
kb_source_builds = [b.build_file("kb", p) for p in KB_FILES + SHARED_FILES]
test_source_builds = [b.build_file("test", p) for p in TEST_FILES]
app_resource_builds = [b.build_file("app", p) for p in RESOURCES]
kb_resource_builds = [b.build_file("kb", p) for p in RESOURCES]
assets_build = b.build_file("app", ROOT / "WeTypeClone" / "Assets.xcassets")
embed_build = b.add(oid(), f"{{isa = PBXBuildFile; fileRef = {kb_product}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }}")

# Groups
def group(name: str, children: list[str], path: str | None = None) -> str:
    value = oid()
    child_text = ",\n".join(children)
    path_line = f'path = "{path}"; ' if path else ""
    b.add(value, f"{{isa = PBXGroup; children = (\n{child_text},\n); {path_line}sourceTree = \"<group>\"; }}")
    return value

app_children = []
app_children.append(group("App", [b.file_refs[p] for p in APP_FILES], "App"))
res_children = [b.file_refs[p] for p in RESOURCES]
app_children.append(group("Resources", res_children, "Resources"))
app_children += [assets_ref, info_ref, ent_ref]
app_group = group("WeTypeClone", app_children, "WeTypeClone")

kb_children = [b.file_refs[p] for p in KB_FILES] + [kb_info_ref, kb_ent_ref]
kb_group = group("Keyboard", kb_children, "Keyboard")
shared_group = group("Shared", shared_refs, "Shared")
test_group = group("WeTypeCloneUITests", test_refs, "WeTypeCloneUITests")

frameworks_group = group("Frameworks", [sqlite_ref])
products_group = group("Products", [app_product, kb_product, test_product])
main_group = group("Main", [app_group, kb_group, shared_group, test_group, frameworks_group, products_group])
b.objects[main_group] = b.objects[main_group].replace('sourceTree = "<group>";', 'sourceTree = "<group>"; ')

# Build phases
def _files(builds: list[str]) -> str:
    return "" if not builds else ",\n".join(builds) + ",\n"

def sources_phase(name: str, builds: list[str]) -> str:
    value = oid()
    b.add(value, f"{{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (\n" + _files(builds) + "); runOnlyForDeploymentPostprocessing = 0; }")
    return value

def resources_phase(builds: list[str]) -> str:
    value = oid()
    b.add(value, f"{{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (\n" + _files(builds) + "); runOnlyForDeploymentPostprocessing = 0; }")
    return value

def frameworks_phase(builds: list[str]) -> str:
    value = oid()
    b.add(value, f"{{isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (\n" + _files(builds) + "); runOnlyForDeploymentPostprocessing = 0; }")
    return value

app_sources = sources_phase("app", app_source_builds)
app_frameworks = frameworks_phase([sqlite_build_app])
app_resources = resources_phase(app_resource_builds + [assets_build])
kb_sources = sources_phase("kb", kb_source_builds)
kb_frameworks = frameworks_phase([sqlite_build_kb])
kb_resources = resources_phase(kb_resource_builds)
test_sources = sources_phase("test", test_source_builds)
test_frameworks = frameworks_phase([xctest_build])
test_resources = resources_phase([])

embed_phase = oid()
b.add(embed_phase, f"{{isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = \"\"; dstSubfolderSpec = 13; files = (\n{embed_build},\n); name = \"Embed Foundation Extensions\"; runOnlyForDeploymentPostprocessing = 0; }}")

proxy = oid()
b.add(proxy, "{isa = PBXContainerItemProxy; containerPortal = PROJECT_ID; proxyType = 1; remoteGlobalIDString = KB_TARGET_ID; remoteInfo = WeTypeKeyboard; }")
dependency = oid()
b.add(dependency, f"{{isa = PBXTargetDependency; target = KB_TARGET_ID; targetProxy = {proxy}; }}")
test_proxy = oid()
b.add(test_proxy, "{isa = PBXContainerItemProxy; containerPortal = PROJECT_ID; proxyType = 1; remoteGlobalIDString = APP_TARGET_ID; remoteInfo = WeTypeClone; }")
test_dependency = oid()
b.add(test_dependency, f"{{isa = PBXTargetDependency; target = APP_TARGET_ID; targetProxy = {test_proxy}; }}")

# Targets
app_target = oid()
kb_target = oid()
test_target = oid()
app_config_list = oid()
kb_config_list = oid()
test_config_list = oid()
project_config_list = oid()

app_target_body = f"""{{
    isa = PBXNativeTarget;
    buildConfigurationList = {app_config_list};
    buildPhases = (
        {app_sources},
        {app_frameworks},
        {app_resources},
        {embed_phase},
    );
    buildRules = ();
    dependencies = (
        {dependency},
    );
    name = WeTypeClone;
    productName = WeTypeClone;
    productReference = {app_product};
    productType = "com.apple.product-type.application";
}}"""
b.add(app_target, app_target_body)

kb_target_body = f"""{{
    isa = PBXNativeTarget;
    buildConfigurationList = {kb_config_list};
    buildPhases = (
        {kb_sources},
        {kb_frameworks},
        {kb_resources},
    );
    buildRules = ();
    dependencies = ();
    name = WeTypeKeyboard;
    productName = WeTypeKeyboard;
    productReference = {kb_product};
    productType = "com.apple.product-type.app-extension";
}}"""
b.add(kb_target, kb_target_body)

test_target_body = f"""{{
    isa = PBXNativeTarget;
    buildConfigurationList = {test_config_list};
    buildPhases = (
        {test_sources},
        {test_frameworks},
        {test_resources},
    );
    buildRules = ();
    dependencies = (
        {test_dependency},
    );
    name = WeTypeCloneUITests;
    productName = WeTypeCloneUITests;
    productReference = {test_product};
    productType = "com.apple.product-type.bundle.ui-testing";
}}"""
b.add(test_target, test_target_body)

# Build configurations
def config(name: str, kind: str) -> str:
    value = oid()
    if kind == "project":
        if name == "Debug":
            settings = """ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";"""
        else:
            settings = """ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				VALIDATE_PRODUCT = YES;"""
    elif kind == "test":
        settings = """CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.huapohen.wechatinput.iosUITests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
				TEST_TARGET_NAME = WeTypeClone;"""
    elif kind == "app":
        settings = """ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = WeTypeClone/WeTypeClone.entitlements;
				"CODE_SIGN_IDENTITY[sdk=iphonesimulator*]" = "-";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = WeTypeClone/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "微输入法";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				OTHER_LDFLAGS = "-lsqlite3";
				PRODUCT_BUNDLE_IDENTIFIER = com.huapohen.wechatinput.ios;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";"""
    else:
        settings = """APPLICATION_EXTENSION_API_ONLY = YES;
				CODE_SIGN_ENTITLEMENTS = Keyboard/Keyboard.entitlements;
				"CODE_SIGN_IDENTITY[sdk=iphonesimulator*]" = "-";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Keyboard/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0.0;
				OTHER_LDFLAGS = "-lsqlite3";
				PRODUCT_BUNDLE_IDENTIFIER = com.huapohen.wechatinput.ios.keyboard;
				PRODUCT_NAME = WeTypeKeyboard;
				SKIP_INSTALL = YES;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";"""
    b.add(value, f"{{isa = XCBuildConfiguration; buildSettings = {{\n\t\t\t\t{settings}\n\t\t\t}}; name = {name}; }}")
    return value

proj_debug = config("Debug", "project")
proj_release = config("Release", "project")
app_debug = config("Debug", "app")
app_release = config("Release", "app")
kb_debug = config("Debug", "kb")
kb_release = config("Release", "kb")
test_debug = config("Debug", "test")
test_release = config("Release", "test")

def config_list(configs: list[str], label: str) -> str:
    value = oid()
    b.add(value, "{isa = XCConfigurationList; buildConfigurations = (\n" + ",\n".join(configs) + f",\n); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }}")
    return value

# config_list currently generates its own id; re-create explicitly for the three lists
b.objects.pop(project_config_list, None)
b.objects.pop(app_config_list, None)
b.objects.pop(kb_config_list, None)
b.add(project_config_list, "{isa = XCConfigurationList; buildConfigurations = (\n" + f"{proj_debug},\n{proj_release},\n" + "); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }")
b.add(app_config_list, "{isa = XCConfigurationList; buildConfigurations = (\n" + f"{app_debug},\n{app_release},\n" + "); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }")
b.add(kb_config_list, "{isa = XCConfigurationList; buildConfigurations = (\n" + f"{kb_debug},\n{kb_release},\n" + "); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }")
b.add(test_config_list, "{isa = XCConfigurationList; buildConfigurations = (\n" + f"{test_debug},\n{test_release},\n" + "); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }")

project_id = oid()
b.add(project_id, f"""{{
    isa = PBXProject;
    attributes = {{
        BuildIndependentTargetsInParallel = 1;
        LastSwiftUpdateCheck = 2700;
        LastUpgradeCheck = 2700;
        TargetAttributes = {{
            {app_target} = {{ CreatedOnToolsVersion = 27.0; }};
            {kb_target} = {{ CreatedOnToolsVersion = 27.0; }};
            {test_target} = {{ CreatedOnToolsVersion = 27.0; TestTargetID = {app_target}; }};
        }};
    }};
    buildConfigurationList = {project_config_list};
    compatibilityVersion = "Xcode 14.0";
    developmentRegion = en;
    hasScannedForEncodings = 0;
    knownRegions = (
        en,
        Base,
        "zh-Hans",
    );
    mainGroup = {main_group};
    productRefGroup = {products_group};
    projectDirPath = "";
    projectRoot = "";
    targets = (
        {app_target},
        {kb_target},
        {test_target},
    );
}}""")

# Resolve forward references used in snippets.
for key, value in list(b.objects.items()):
    value = value.replace("PROJECT_ID", project_id).replace("KB_TARGET_ID", kb_target).replace("APP_TARGET_ID", app_target).replace("TEST_TARGET_ID", test_target)
    b.objects[key] = value

parts = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {};", "\tobjectVersion = 56;", "\tobjects = {"]
for key in sorted(b.objects):
    body = b.objects[key]
    parts.append(f"\t\t{key} = {body};")
parts += ["\t};", f"\trootObject = {project_id};", "}"]
PROJECT.mkdir(parents=True, exist_ok=True)
PBX.write_text("\n".join(parts) + "\n", encoding="utf-8")

# Scheme
schemes = PROJECT / "xcshareddata" / "xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "2700" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{app_target}" BuildableName = "WeTypeClone.app" BlueprintName = "WeTypeClone" ReferencedContainer = "container:WeTypeClone.xcodeproj"/>
         </BuildActionEntry>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "NO" buildForProfiling = "NO" buildForArchiving = "NO" buildForAnalyzing = "NO">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{test_target}" BuildableName = "WeTypeCloneUITests.xctest" BlueprintName = "WeTypeCloneUITests" ReferencedContainer = "container:WeTypeClone.xcodeproj"/>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference skipped = "NO">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{test_target}" BuildableName = "WeTypeCloneUITests.xctest" BlueprintName = "WeTypeCloneUITests" ReferencedContainer = "container:WeTypeClone.xcodeproj"/>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{app_target}" BuildableName = "WeTypeClone.app" BlueprintName = "WeTypeClone" ReferencedContainer = "container:WeTypeClone.xcodeproj"/>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{app_target}" BuildableName = "WeTypeClone.app" BlueprintName = "WeTypeClone" ReferencedContainer = "container:WeTypeClone.xcodeproj"/>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"/>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"/>
</Scheme>
"""
(schemes / "WeTypeClone.xcscheme").write_text(scheme, encoding="utf-8")

print(f"wrote {PBX}")
print(f"app sources {len(APP_FILES)}, shared {len(SHARED_FILES)}, keyboard {len(KB_FILES)}, resources {len(RESOURCES)}")
