from pathlib import Path
import hashlib
root=Path(__file__).resolve().parent.parent
uid=lambda s:hashlib.sha1(s.encode()).hexdigest()[:24].upper()
objects=[]
def obj(key,body):
 objects.append(f'{uid(key)} = {{ {body} }};');return uid(key)
files=sorted(list((root/'MagicMousePlus').rglob('*.swift'))+list((root/'MagicMousePlus').rglob('*.c')))
refs=[]; builds=[]
for path in files:
 rel=path.relative_to(root).as_posix(); typ='sourcecode.swift' if path.suffix=='.swift' else 'sourcecode.c.c'
 refs.append(obj(rel,f'isa = PBXFileReference; lastKnownFileType = {typ}; path = "{rel}"; sourceTree = SOURCE_ROOT;'))
 builds.append(obj('build'+rel,f'isa = PBXBuildFile; fileRef = {uid(rel)};'))
product=obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = "Magic Mouse +.app"; sourceTree = BUILT_PRODUCTS_DIR;')
obj('rootgroup',f'isa = PBXGroup; children = ({",".join(refs+[uid("products")])}); sourceTree = "<group>";')
obj('products',f'isa = PBXGroup; children = ({product}); name = Products; sourceTree = "<group>";')
obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')
obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
obj('resources','isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
for mode in ['Debug','Release']:
 obj('project'+mode,f'isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ SDKROOT = macosx; MACOSX_DEPLOYMENT_TARGET = 13.0; CLANG_ENABLE_MODULES = YES; SWIFT_VERSION = 5.0; GCC_C_LANGUAGE_STANDARD = gnu17; }};')
 opt='-Onone' if mode=='Debug' else '-O'
 inject='YES' if mode=='Debug' else 'NO'
 obj('target'+mode,f'''isa = XCBuildConfiguration; name = {mode}; buildSettings = {{ PRODUCT_NAME = "Magic Mouse +"; PRODUCT_MODULE_NAME = MagicMousePlus; PRODUCT_BUNDLE_IDENTIFIER = com.mustafakavalci.magicmouseplus; INFOPLIST_FILE = MagicMousePlus/Info.plist; GENERATE_INFOPLIST_FILE = NO; SWIFT_OBJC_BRIDGING_HEADER = "MagicMousePlus/Bridge/TouchBridge.h"; CODE_SIGN_INJECT_BASE_ENTITLEMENTS = {inject}; CODE_SIGN_STYLE = Automatic; CODE_SIGN_IDENTITY = "-"; ENABLE_APP_SANDBOX = NO; ENABLE_HARDENED_RUNTIME = YES; SWIFT_OPTIMIZATION_LEVEL = "{opt}"; COMBINE_HIDPI_IMAGES = YES; }};''')
for scope in ['project','target']:
 obj(scope+'configs',f'isa = XCConfigurationList; buildConfigurations = ({uid(scope+"Debug")},{uid(scope+"Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({uid("sources")},{uid("frameworks")},{uid("resources")}); buildRules = (); dependencies = (); name = MagicMousePlus; productName = "Magic Mouse +"; productReference = {product}; productType = "com.apple.product-type.application";')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2660; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = {uid("rootgroup")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")});')
(root/'MagicMousePlus.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+uid('project')+'; }\n')
(root/'MagicMousePlus.xcodeproj/xcshareddata/xcschemes/MagicMousePlus.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="Magic Mouse +.app" BlueprintName="MagicMousePlus" ReferencedContainer="container:MagicMousePlus.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="Magic Mouse +.app" BlueprintName="MagicMousePlus" ReferencedContainer="container:MagicMousePlus.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
