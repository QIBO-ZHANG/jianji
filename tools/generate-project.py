#!/usr/bin/env python3
"""Emit a classic, explicitly-file-referenced project.pbxproj for the skeleton."""
import hashlib
import os
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT_NAME = "AppSkeleton"
BUNDLE_ID = "com.example.appskeleton"
DEPLOYMENT_TARGET = "18.0"

counter = defaultdict(int)


def ident(key):
    counter[key] += 1
    seed = f"{key}#{counter[key]}"
    return hashlib.md5(seed.encode()).hexdigest().upper()[:24]


def build_tree(base_rel):
    """Return (group_uuid, children_spec) for a source folder."""
    abs_base = os.path.join(ROOT, base_rel)
    entries = sorted(os.listdir(abs_base))
    children = []
    for entry in entries:
        abs_path = os.path.join(abs_base, entry)
        rel = f"{base_rel}/{entry}"
        if os.path.isdir(abs_path):
            if entry.endswith((".xcassets", ".xcdatamodeld", ".xcodeproj")):
                children.append(file_entry(rel, entry))
            else:
                children.append(group_node(rel))
        elif entry.endswith((".swift", ".metal", ".plist", ".strings", ".xcstrings")):
            children.append(file_entry(rel, entry))
    return group_node(base_rel, children)


refs = {}


def file_ref(rel, name):
    if rel not in refs:
        refs[rel] = (ident("file"), name)
    return refs[rel]


def file_entry(rel, name):
    uuid, _ = file_ref(rel, name)
    return f"\t\t{uuid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type(name)}; path = {quote(name)}; sourceTree = \"<group>\"; }};\n"


def file_type(name):
    if name.endswith(".swift"):
        return "sourcecode.swift"
    if name.endswith(".xcassets"):
        return "folder.assetcatalog"
    if name.endswith(".plist"):
        return "text.plist.xml"
    return "text"


def quote(value):
    if any(ch in value for ch in " \t\"()/"):
        return '"' + value.replace('"', '\\"') + '"'
    return value


def collect(rel):
    """Register a file (and its line) without placing it yet."""
    name = os.path.basename(rel)
    uuid, _ = file_ref(rel, name)
    collect.lines.append(file_entry(rel, name))
    return uuid


collect.lines = []


def group_node(rel, child_lines=None):
    uuid = ident("group")
    name = os.path.basename(rel)
    path = rel if "/" in rel or "." in rel else rel
    lines = [f"\t\t{uuid} /* {name} */ = {{\n", "\t\t\tisa = PBXGroup;\n", "\t\t\tchildren = (\n"]
    lines.extend(child_lines or [])
    lines.append("\t\t\t);\n")
    lines.append(f"\t\t\tpath = {quote(path)};\n")
    lines.append("\t\t\tsourceTree = \"<group>\";\n")
    lines.append("\t\t};\n")
    return "".join(lines)


# ---------------------------------------------------------------- source files
def swift_files(rel):
    abs_base = os.path.join(ROOT, rel)
    found = []
    for dirpath, _, filenames in os.walk(abs_base):
        for filename in sorted(filenames):
            if filename.endswith(".swift"):
                found.append(os.path.relpath(os.path.join(dirpath, filename), ROOT))
    return sorted(found)


app_swift = swift_files("AppSkeleton")
test_swift = swift_files("AppSkeletonTests")
ui_swift = swift_files("AppSkeletonUITests")

# Build file objects (Sources phase)
app_sources = [(file_ref(rel, os.path.basename(rel))[0], ident("buildfile"), os.path.basename(rel)) for rel in app_swift]
test_sources = [(file_ref(rel, os.path.basename(rel))[0], ident("buildfile"), os.path.basename(rel)) for rel in test_swift]
ui_sources = [(file_ref(rel, os.path.basename(rel))[0], ident("buildfile"), os.path.basename(rel)) for rel in ui_swift]

assets_rel = "AppSkeleton/Resources/Assets.xcassets"
assets_file = file_ref(assets_rel, "Assets.xcassets")[0]
assets_build = ident("buildfile")
info_rel = "Supporting/Info.plist"
info_file = file_ref(info_rel, "Info.plist")[0]

app_product = ident("product")
test_product = ident("product")
ui_product = ident("product")
app_target = ident("target")
test_target = ident("target")
ui_target = ident("target")
app_insane = ident("buildphase-sources")
test_insane = ident("buildphase-sources")
ui_insane = ident("buildphase-sources")
app_resources = ident("buildphase-resources")
app_frameworks = ident("buildphase-frameworks")
test_frameworks = ident("buildphase-frameworks")
ui_frameworks = ident("buildphase-frameworks")
app_dependencies = ident("dep-list")
proxy = ident("proxy")
ui_proxy = ident("proxy")
container = ident("container")
group_dep = ident("targetdep")
ui_dep = ident("targetdep")
project_obj = ident("project")
main_group = ident("group")
products_group = ident("group")
supporting_group = ident("group")
config_list_project = ident("cfglist")
config_list_app = ident("cfglist")
config_list_test = ident("cfglist")
config_list_ui = ident("cfglist")
debug_project, release_project = ident("cfg"), ident("cfg")
debug_app, release_app = ident("cfg"), ident("cfg")
debug_test, release_test = ident("cfg"), ident("cfg")
debug_ui, release_ui = ident("cfg"), ident("cfg")

# Groups: rebuild nested group tree for app + tests
def nested_group_tree(rel_base):
    """Return (leaf_file_lines, ordered_group_definitions, root_child_refs)."""
    file_lines = []
    group_defs = []
    tree = defaultdict(lambda: ({}, set()))  # dir -> (subdir -> uuid, files)

    dirs = sorted({os.path.dirname(os.path.join(rel_base, rel)) for rel in [r for r in map(lambda x: x[0], [])] } | set())
    return file_lines, group_defs, dirs


def group_tree_for(rel_base, registered_sources):
    abs_base = os.path.join(ROOT, rel_base)
    entries = sorted(os.listdir(abs_base))
    child_refs = []
    extra_lines = []
    for entry in entries:
        abs_path = os.path.join(abs_base, entry)
        rel = f"{rel_base}/{entry}"
        if os.path.isdir(abs_path):
            if entry.endswith(".xcassets"):
                uuid, _ = file_ref(rel, entry)
                child_refs.append(f"\t\t\t\t{uuid} /* {entry} */,\n")
            else:
                subtree_refs, subtree_lines = group_tree_for(rel, registered_sources)
                extra_lines.extend(subtree_lines)
                uuid = ident("group")
                extra_lines.append(
                    f"\t\t{uuid} /* {entry} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
                    + "".join(subtree_refs)
                    + f"\t\t\t);\n\t\t\tpath = {quote(entry)};\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n"
                )
                child_refs.append(f"\t\t\t\t{uuid} /* {entry} */,\n")
        elif entry.endswith(".swift"):
            uuid, _ = file_ref(rel, entry)
            child_refs.append(f"\t\t\t\t{uuid} /* {entry} */,\n")
    return child_refs, extra_lines


app_child_refs, app_group_lines = group_tree_for("AppSkeleton", app_sources)
test_child_refs, test_group_lines = group_tree_for("AppSkeletonTests", test_sources)
ui_child_refs, ui_group_lines = group_tree_for("AppSkeletonUITests", ui_sources)

app_group_uuid = ident("group")
test_group_uuid = ident("group")
ui_group_uuid = ident("group")

pbx = []
pbx.append("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 56;\n")
pbx.append(f"\tobjects = {{\n\n/* Begin PBXBuildFile section */\n")
for file_uuid, build_uuid, name in app_sources:
    pbx.append(f"\t\t{build_uuid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {name} */; }};\n")
for file_uuid, build_uuid, name in test_sources:
    pbx.append(f"\t\t{build_uuid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {name} */; }};\n")
for file_uuid, build_uuid, name in ui_sources:
    pbx.append(f"\t\t{build_uuid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {name} */; }};\n")
pbx.append(f"\t\t{assets_build} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_file} /* Assets.xcassets */; }};\n")
pbx.append("/* End PBXBuildFile section */\n\n/* Begin PBXContainerItemProxy section */\n")
pbx.append(
    f"\t\t{proxy} /* PBXContainerItemProxy */ = {{\n\t\t\tisa = PBXContainerItemProxy;\n"
    f"\t\t\tcontainerPortal = {project_obj} /* Project object */;\n\t\t\tproxyType = 1;\n"
    f"\t\t\tremoteGlobalIDString = {app_target};\n\t\t\tremoteInfo = {PROJECT_NAME};\n\t\t}};\n"
)
pbx.append(
    f"\t\t{ui_proxy} /* PBXContainerItemProxy */ = {{\n\t\t\tisa = PBXContainerItemProxy;\n"
    f"\t\t\tcontainerPortal = {project_obj} /* Project object */;\n\t\t\tproxyType = 1;\n"
    f"\t\t\tremoteGlobalIDString = {app_target};\n\t\t\tremoteInfo = {PROJECT_NAME};\n\t\t}};\n"
)
pbx.append("/* End PBXContainerItemProxy section */\n\n/* Begin PBXFileReference section */\n")
for rel, (uuid, name) in sorted(refs.items(), key=lambda kv: kv[0]):
    pbx.append(file_entry(rel, name))
pbx.append(
    f"\t\t{app_product} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; "
    f"includeInIndex = 0; path = {PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
)
pbx.append(
    f"\t\t{test_product} /* {PROJECT_NAME}Tests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cocoa-touch-bundle; "
    f"includeInIndex = 0; path = {PROJECT_NAME}Tests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
)
pbx.append(
    f"\t\t{ui_product} /* {PROJECT_NAME}UITests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cocoa-touch-bundle; "
    f"includeInIndex = 0; path = {PROJECT_NAME}UITests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};\n"
)
pbx.append("/* End PBXFileReference section */\n\n/* Begin PBXFrameworksBuildPhase section */\n")
pbx.append(f"\t\t{app_frameworks} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\tname = Frameworks;\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n")
pbx.append(f"\t\t{test_frameworks} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\tname = Frameworks;\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n")
pbx.append(f"\t\t{ui_frameworks} /* Frameworks */ = {{\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\tname = Frameworks;\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n")
pbx.append("/* End PBXFrameworksBuildPhase section */\n\n/* Begin PBXGroup section */\n")
pbx.append(
    f"\t\t{main_group} = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
    f"\t\t\t\t{app_group_uuid} /* {PROJECT_NAME} */,\n"
    f"\t\t\t\t{test_group_uuid} /* {PROJECT_NAME}Tests */,\n"
    f"\t\t\t\t{ui_group_uuid} /* {PROJECT_NAME}UITests */,\n"
    f"\t\t\t\t{supporting_group} /* Supporting */,\n"
    f"\t\t\t\t{products_group} /* Products */,\n"
    "\t\t\t);\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n"
)
pbx.append(
    f"\t\t{app_group_uuid} /* {PROJECT_NAME} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
    + "".join(app_child_refs)
    + f"\t\t\t);\n\t\t\tpath = {PROJECT_NAME};\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n"
)
pbx.append(
    f"\t\t{test_group_uuid} /* {PROJECT_NAME}Tests */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
    + "".join(test_child_refs)
    + f"\t\t\t);\n\t\t\tpath = {PROJECT_NAME}Tests;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n"
)
pbx.append(
    f"\t\t{ui_group_uuid} /* {PROJECT_NAME}UITests */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
    + "".join(ui_child_refs)
    + f"\t\t\t);\n\t\t\tpath = {PROJECT_NAME}UITests;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n"
)
pbx.append(
    f"\t\t{supporting_group} /* Supporting */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
    f"\t\t\t\t{info_file} /* Info.plist */,\n"
    f"\t\t\t);\n\t\t\tpath = Supporting;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n"
)
pbx.append(
    f"\t\t{products_group} /* Products */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n"
    f"\t\t\t\t{app_product} /* {PROJECT_NAME}.app */,\n"
    f"\t\t\t\t{test_product} /* {PROJECT_NAME}Tests.xctest */,\n"
    f"\t\t\t\t{ui_product} /* {PROJECT_NAME}UITests.xctest */,\n"
    f"\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = \"<group>\";\n\t\t}};\n"
)
pbx.extend(app_group_lines)
pbx.append("/* End PBXGroup section */\n\n/* Begin PBXNativeTarget section */\n")
pbx.append(
    f"\t\t{app_target} /* {PROJECT_NAME} */ = {{\n\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {config_list_app} /* Build configuration list for PBXNativeTarget \"{PROJECT_NAME}\" */;\n"
    f"\t\t\tbuildPhases = (\n\t\t\t\t{app_insane} /* Sources */,\n\t\t\t\t{app_frameworks} /* Frameworks */,\n\t\t\t\t{app_resources} /* Resources */,\n\t\t\t);\n"
    f"\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = {PROJECT_NAME};\n"
    f"\t\t\tproductName = {PROJECT_NAME};\n\t\t\tproductReference = {app_product} /* {PROJECT_NAME}.app */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.application\";\n\t\t}};\n"
)
pbx.append(
    f"\t\t{test_target} /* {PROJECT_NAME}Tests */ = {{\n\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {config_list_test} /* Build configuration list for PBXNativeTarget \"{PROJECT_NAME}Tests\" */;\n"
    f"\t\t\tbuildPhases = (\n\t\t\t\t{test_insane} /* Sources */,\n\t\t\t\t{test_frameworks} /* Frameworks */,\n\t\t\t);\n"
    f"\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t\t{group_dep} /* PBXTargetDependency */,\n\t\t\t);\n"
    f"\t\t\tname = {PROJECT_NAME}Tests;\n\t\t\tproductName = {PROJECT_NAME}Tests;\n"
    f"\t\t\tproductReference = {test_product} /* {PROJECT_NAME}Tests.xctest */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";\n\t\t}};\n"
)
pbx.append(
    f"\t\t{ui_target} /* {PROJECT_NAME}UITests */ = {{\n\t\t\tisa = PBXNativeTarget;\n"
    f"\t\t\tbuildConfigurationList = {config_list_ui} /* Build configuration list for PBXNativeTarget \"{PROJECT_NAME}UITests\" */;\n"
    f"\t\t\tbuildPhases = (\n\t\t\t\t{ui_insane} /* Sources */,\n\t\t\t\t{ui_frameworks} /* Frameworks */,\n\t\t\t);\n"
    f"\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t\t{ui_dep} /* PBXTargetDependency */,\n\t\t\t);\n"
    f"\t\t\tname = {PROJECT_NAME}UITests;\n\t\t\tproductName = {PROJECT_NAME}UITests;\n"
    f"\t\t\tproductReference = {ui_product} /* {PROJECT_NAME}UITests.xctest */;\n"
    f"\t\t\tproductType = \"com.apple.product-type.bundle.ui-testing\";\n\t\t}};\n"
)
pbx.append("/* End PBXNativeTarget section */\n\n/* Begin PBXProject section */\n")
pbx.append(
    f"\t\t{project_obj} /* Project object */ = {{\n\t\t\tisa = PBXProject;\n"
    f"\t\t\tattributes = {{\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n\t\t\t\tLastSwiftUpdateCheck = 2700;\n"
    f"\t\t\t\tLastUpgradeCheck = 2700;\n\t\t\t\tTargetAttributes = {{\n"
    f"\t\t\t\t\t{app_target} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 27.0;\n\t\t\t\t\t}};\n"
    f"\t\t\t\t\t{test_target} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 27.0;\n\t\t\t\t\t\tTargetAttributes = {{\n"
    f"\t\t\t\t\t\t}};\n\t\t\t\t\t\tTestTargetID = {app_target};\n\t\t\t\t\t}};\n"
    f"\t\t\t\t\t{ui_target} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 27.0;\n\t\t\t\t\t}};\n"
    "\t\t\t\t};\n\t\t\t};\n"
    f"\t\t\tbuildConfigurationList = {config_list_project} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;\n"
    "\t\t\tcompatibilityVersion = \"Xcode 14.0\";\n\t\t\tdevelopmentRegion = en;\n"
    "\t\t\thasScannedForEncodings = 0;\n\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n"
    f"\t\t\tmainGroup = {main_group};\n\t\t\tproductRefGroup = {products_group} /* Products */;\n"
    "\t\t\tprojectDirPath = \"\";\n\t\t\tprojectRoot = \"\";\n"
    f"\t\t\ttargets = (\n\t\t\t\t{app_target} /* {PROJECT_NAME} */,\n\t\t\t\t{test_target} /* {PROJECT_NAME}Tests */,\n"
    f"\t\t\t\t{ui_target} /* {PROJECT_NAME}UITests */,\n\t\t\t);\n\t\t}};\n"
)
pbx.append("/* End PBXProject section */\n\n/* Begin PBXResourcesBuildPhase section */\n")
pbx.append(
    f"\t\t{app_resources} /* Resources */ = {{\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
    f"\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,\n"
    "\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n"
)
pbx.append("/* End PBXResourcesBuildPhase section */\n\n/* Begin PBXSourcesBuildPhase section */\n")
pbx.append(
    f"\t\t{app_insane} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
    + "".join(f"\t\t\t\t{b} /* {n} in Sources */,\n" for _, b, n in app_sources)
    + "\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n"
)
pbx.append(
    f"\t\t{test_insane} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
    + "".join(f"\t\t\t\t{b} /* {n} in Sources */,\n" for _, b, n in test_sources)
    + "\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n"
)
pbx.append(
    f"\t\t{ui_insane} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
    + "".join(f"\t\t\t\t{b} /* {n} in Sources */,\n" for _, b, n in ui_sources)
    + "\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n"
)
pbx.append("/* End PBXSourcesBuildPhase section */\n\n/* Begin PBXTargetDependency section */\n")
pbx.append(
    f"\t\t{group_dep} /* PBXTargetDependency */ = {{\n\t\t\tisa = PBXTargetDependency;\n"
    f"\t\t\ttarget = {app_target} /* {PROJECT_NAME} */;\n\t\t\ttargetProxy = {proxy} /* PBXContainerItemProxy */;\n\t\t}};\n"
)
pbx.append(
    f"\t\t{ui_dep} /* PBXTargetDependency */ = {{\n\t\t\tisa = PBXTargetDependency;\n"
    f"\t\t\ttarget = {app_target} /* {PROJECT_NAME} */;\n\t\t\ttargetProxy = {ui_proxy} /* PBXContainerItemProxy */;\n\t\t}};\n"
)
pbx.append("/* End PBXTargetDependency section */\n\n/* Begin XCBuildConfiguration section */\n")

COMMON_PROJECT = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = %s;
\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
\t\t\t\tMTE_ENABLE_INVALID_BUNDLE_ID_ERROR = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
""" % DEPLOYMENT_TARGET

RELEASE_PROJECT = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_COMMA = YES;
\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;
\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;
\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;
\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
\t\t\t\tCLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;
\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;
\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = %s;
\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
\t\t\t\tMTE_ENABLE_INVALID_BUNDLE_ID_ERROR = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tVALIDATE_PRODUCT = YES;
""" % DEPLOYMENT_TARGET


def config(uuid, name, settings, comment=""):
    return (
        f"\t\t{uuid} /* {name} */ = {{\n\t\t\tisa = XCBuildConfiguration;\n"
        f"\t\t\tbuildSettings = {{\n{settings}\t\t\t}};\n\t\t\tname = {name};{comment}\n\t\t}};\n"
    )


APP_SETTINGS = """\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_ASSET_PATHS = "";
\t\t\t\tENABLE_DEBUG_DYLIB = NO;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = Supporting/Info.plist;
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = %s;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = %s;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
""" % (DEPLOYMENT_TARGET, BUNDLE_ID)

TEST_SETTINGS = """\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = %s;
\t\t\t\tMARKETING_VERSION = 0.1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = %s.tests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/%s.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/%s";
""" % (DEPLOYMENT_TARGET, BUNDLE_ID, PROJECT_NAME, PROJECT_NAME)


pbx.append(config(debug_project, "Debug", COMMON_PROJECT))
pbx.append(config(release_project, "Release", RELEASE_PROJECT))
pbx.append(config(debug_app, "Debug", APP_SETTINGS))
pbx.append(config(release_app, "Release", APP_SETTINGS))
UI_SETTINGS = """\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = %s;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = %s.uitests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tTEST_TARGET_NAME = AppSkeleton;
""" % (DEPLOYMENT_TARGET, BUNDLE_ID)

pbx.append(config(debug_ui, "Debug", UI_SETTINGS))
pbx.append(config(release_ui, "Release", UI_SETTINGS))
pbx.append(config(debug_test, "Debug", TEST_SETTINGS))
pbx.append(config(release_test, "Release", TEST_SETTINGS))
pbx.append("/* End XCBuildConfiguration section */\n\n/* Begin XCConfigurationList section */\n")


def cfg_list(uuid, comment, debug_uuid, release_uuid):
    return (
        f"\t\t{uuid} /* {comment} */ = {{\n\t\t\tisa = XCConfigurationList;\n\t\t\tbuildConfigurations = (\n"
        f"\t\t\t\t{debug_uuid} /* Debug */,\n\t\t\t\t{release_uuid} /* Release */,\n"
        "\t\t\t);\n\t\t\tdefaultConfigurationIsVisible = 0;\n\t\t\tdefaultConfigurationName = Release;\n\t\t};\n"
    )


pbx.append(cfg_list(config_list_project, f"Build configuration list for PBXProject \"{PROJECT_NAME}\"", debug_project, release_project))
pbx.append(cfg_list(config_list_app, f"Build configuration list for PBXNativeTarget \"{PROJECT_NAME}\"", debug_app, release_app))
pbx.append(cfg_list(config_list_test, f"Build configuration list for PBXNativeTarget \"{PROJECT_NAME}Tests\"", debug_test, release_test))
pbx.append(cfg_list(config_list_ui, f"Build configuration list for PBXNativeTarget \"{PROJECT_NAME}UITests\"", debug_ui, release_ui))
pbx.append("/* End XCConfigurationList section */\n\t};\n")
pbx.append(f"\trootObject = {project_obj} /* Project object */;\n}}\n")

output_dir = os.path.join(ROOT, f"{PROJECT_NAME}.xcodeproj")
os.makedirs(output_dir, exist_ok=True)
with open(os.path.join(output_dir, "project.pbxproj"), "w") as handle:
    handle.write("".join(pbx))

SCHEME = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2700"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "%(app)s"
               BuildableName = "%(name)s.app"
               BlueprintName = "%(name)s"
               ReferencedContainer = "container:%(name)s.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "%(test)s"
               BuildableName = "%(name)sTests.xctest"
               BlueprintName = "%(name)sTests"
               ReferencedContainer = "container:%(name)s.xcodeproj">
            </BuildableReference>
         </TestableReference>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "%(ui)s"
               BuildableName = "%(name)sUITests.xctest"
               BlueprintName = "%(name)sUITests"
               ReferencedContainer = "container:%(name)s.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "%(app)s"
            BuildableName = "%(name)s.app"
            BlueprintName = "%(name)s"
            ReferencedContainer = "container:%(name)s.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "%(app)s"
            BuildableName = "%(name)s.app"
            BlueprintName = "%(name)s"
            ReferencedContainer = "container:%(name)s.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
""" % {"app": app_target, "test": test_target, "ui": ui_target, "name": PROJECT_NAME}

scheme_dir = os.path.join(output_dir, "xcshareddata", "xcschemes")
os.makedirs(scheme_dir, exist_ok=True)
with open(os.path.join(scheme_dir, f"{PROJECT_NAME}.xcscheme"), "w") as handle:
    handle.write(SCHEME)

import re as _re

text = "".join(pbx)
_group_section = _re.search(r"/\* Begin PBXGroup section \*/(.*?)/\* End PBXGroup", text, _re.S)
_group_children = set(_re.findall(r"^\t{4}([0-9A-F]{24})", _group_section.group(1), _re.M))
orphaned = [name for file_uuid, _, name in app_sources + test_sources + ui_sources if file_uuid not in _group_children]
assert not orphaned, f"sources not reachable from any group: {orphaned}"
assert text.count("isa = PBXFileReference") == len(refs) + 3, "duplicate file references"

print("app sources:", len(app_sources), "test sources:", len(test_sources), "ui sources:", len(ui_sources))
print("wrote", os.path.join(output_dir, "project.pbxproj"))
