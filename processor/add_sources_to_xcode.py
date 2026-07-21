#!/usr/bin/env python3
"""Safely add new files to processor.xcodeproj sections."""
import uuid
from pathlib import Path

PBX = Path(__file__).resolve().parent / "processor.xcodeproj/project.pbxproj"

NEW_SWIFT = [
    "LMHumanFrameSnapshot.swift",
    "LMHumanMaskDerivation.swift",
    "LMHumanUnderstandingService.swift",
    "LMUploadReferenceCardView.swift",
    "LMAgentIconProvider.swift",
    "LMLiquidGlassHUDTokens.swift",
    "LMCoachingEdgeLitBar.swift",
    "LMCoachingActionPill.swift",
    "LMCoachingBubbleView.swift",
    "LMConcentricScoreDonutView.swift",
    "LMScoreDonutOverlayView.swift",
    "LMCameraPage+AgentCoaching.swift",
    "LMCompositionScore.swift",
    "LMScoreFusionEngine.swift",
    "LMCompositionMath.swift",
    "LMCompositionAnalyzer.swift",
    "LMCompositionScoreLoop.swift",
    "LMGlobalStructureScorer.swift",
    "LMGeometricScorer.swift",
    "LMHumanSceneScorer.swift",
    "LMCoachingPolicyConfig.swift",
    "LMConfigRepository.swift",
    "LMDashScopeChatClient.swift",
    "LMCoachingSupport.swift",
    "LMPromptBuilder.swift",
    "LMArbiter.swift",
    "LMActionExecutor.swift",
    "LMExecutionToolRouter.swift",
    "LMAgenticCoachingLoop.swift",
    "LMDepthEstimationService.swift",
    "LMAgentCoachingController.swift",
]

NEW_RESOURCES = [
    ("DepthAnythingV2SmallF16P6.mlpackage", "folder.mlpackage"),
    ("app_config.json", "text.json"),
    ("coaching_policy.json", "text.json"),
]

def gen_id():
    return uuid.uuid4().hex[:24].upper()

def main():
    text = PBX.read_text()
    build_entries = []
    file_entries = []
    source_refs = []
    resource_refs = []

    for name in NEW_SWIFT:
        if f"/* {name} */" in text or f"path = {name};" in text:
            print(f"skip {name}")
            continue
        fid, bid = gen_id(), gen_id()
        build_entries.append(
            f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};"
        )
        file_entries.append(
            f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};"
        )
        source_refs.append(f"\t\t\t\t{bid} /* {name} in Sources */,")

    for name, ftype in NEW_RESOURCES:
        if f"path = {name};" in text:
            print(f"skip {name}")
            continue
        fid, bid = gen_id(), gen_id()
        phase = "Resources" if ftype in ("folder.mlpackage", "text.json") else "Sources"
        build_entries.append(
            f"\t\t{bid} /* {name} in {phase} */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};"
        )
        file_entries.append(
            f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {name}; sourceTree = \"<group>\"; }};"
        )
        if phase == "Resources":
            resource_refs.append(f"\t\t\t\t{bid} /* {name} in Resources */,")
        else:
            source_refs.append(f"\t\t\t\t{bid} /* {name} in Sources */,")

    if not build_entries:
        print("Nothing to add")
        return

    text = text.replace(
        "/* Begin PBXBuildFile section */\n",
        "/* Begin PBXBuildFile section */\n" + "\n".join(build_entries) + "\n",
        1,
    )
    text = text.replace(
        "/* Begin PBXFileReference section */\n",
        "/* Begin PBXFileReference section */\n" + "\n".join(file_entries) + "\n",
        1,
    )
    text = text.replace(
        "/* Begin PBXSourcesBuildPhase section */\n\t\tEACA1BED2E7E408900C80883 /* Sources */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n",
        "/* Begin PBXSourcesBuildPhase section */\n\t\tEACA1BED2E7E408900C80883 /* Sources */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n" + "\n".join(source_refs) + "\n",
        1,
    )

    if resource_refs:
        text = text.replace(
            "/* Begin PBXResourcesBuildPhase section */\n\t\tEACA1BEF2E7E408900C80883 /* Resources */ = {\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n",
            "/* Begin PBXResourcesBuildPhase section */\n\t\tEACA1BEF2E7E408900C80883 /* Resources */ = {\n\t\t\tisa = PBXResourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n" + "\n".join(resource_refs) + "\n",
            1,
        )

    PBX.write_text(text)
    print(f"Added {len(build_entries)} files")

if __name__ == "__main__":
    main()
