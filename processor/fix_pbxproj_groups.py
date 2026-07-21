#!/usr/bin/env python3
"""Add PBX groups and wire file references for Agentic Guidance parity files."""
from pathlib import Path

PBX = Path(__file__).resolve().parent / "processor.xcodeproj/project.pbxproj"

# Group IDs (new)
G_COACHING = "EA5700502EC10002000AB522"
G_COACH_COMP = "EA5700512EC10002000AB522"
G_COACH_SCORING = "EA5700522EC10002000AB522"
G_COACH_CONFIG = "EA5700532EC10002000AB522"
G_COACH_LLM = "EA5700542EC10002000AB522"
G_COACH_AGENT = "EA5700552EC10002000AB522"
G_COACH_MGR = "EA5700562EC10002000AB522"
G_RES_CONFIG = "EA5700572EC10002000AB522"

text = PBX.read_text()

# --- Insert coaching groups before /* End PBXGroup section */ ---
coaching_groups = f"""
\t\t{G_COACH_SCORING} /* scoring */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tEA5700222EC10001000AB522 /* LMGlobalStructureScorer.swift */,
\t\t\t\tEA5700242EC10001000AB522 /* LMGeometricScorer.swift */,
\t\t\t\tEA5700262EC10001000AB522 /* LMHumanSceneScorer.swift */,
\t\t\t);
\t\t\tpath = scoring;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{G_COACH_COMP} /* composition */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tEA5700182EC10001000AB522 /* LMCompositionScore.swift */,
\t\t\t\tEA57001A2EC10001000AB522 /* LMScoreFusionEngine.swift */,
\t\t\t\tEA57001C2EC10001000AB522 /* LMCompositionMath.swift */,
\t\t\t\tEA57001E2EC10001000AB522 /* LMCompositionAnalyzer.swift */,
\t\t\t\tEA5700202EC10001000AB522 /* LMCompositionScoreLoop.swift */,
\t\t\t\t{G_COACH_SCORING} /* scoring */,
\t\t\t);
\t\t\tpath = composition;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{G_COACH_CONFIG} /* config */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tEA5700282EC10001000AB522 /* LMCoachingPolicyConfig.swift */,
\t\t\t\tEA57002A2EC10001000AB522 /* LMConfigRepository.swift */,
\t\t\t);
\t\t\tpath = config;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{G_COACH_LLM} /* llm */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tEA57002C2EC10001000AB522 /* LMDashScopeChatClient.swift */,
\t\t\t);
\t\t\tpath = llm;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{G_COACH_AGENT} /* agent */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tEA57002E2EC10001000AB522 /* LMCoachingSupport.swift */,
\t\t\t\tEA5700302EC10001000AB522 /* LMPromptBuilder.swift */,
\t\t\t\tEA5700322EC10001000AB522 /* LMArbiter.swift */,
\t\t\t\tEA5700342EC10001000AB522 /* LMActionExecutor.swift */,
\t\t\t\tEA5700362EC10001000AB522 /* LMExecutionToolRouter.swift */,
\t\t\t\tEA5700382EC10001000AB522 /* LMAgenticCoachingLoop.swift */,
\t\t\t);
\t\t\tpath = agent;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{G_COACH_MGR} /* managers */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tEA57003A2EC10001000AB522 /* LMDepthEstimationService.swift */,
\t\t\t\tEA57003C2EC10001000AB522 /* LMAgentCoachingController.swift */,
\t\t\t);
\t\t\tpath = managers;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{G_COACHING} /* coaching */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{G_COACH_COMP} /* composition */,
\t\t\t\t{G_COACH_CONFIG} /* config */,
\t\t\t\t{G_COACH_LLM} /* llm */,
\t\t\t\t{G_COACH_AGENT} /* agent */,
\t\t\t\t{G_COACH_MGR} /* managers */,
\t\t\t);
\t\t\tpath = coaching;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{G_RES_CONFIG} /* config */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tEA5700402EC10001000AB522 /* app_config.json */,
\t\t\t\tEA5700412EC10001000AB522 /* coaching_policy.json */,
\t\t\t);
\t\t\tpath = config;
\t\t\tsourceTree = "<group>";
\t\t}};
"""

if G_COACHING not in text:
    text = text.replace("/* End PBXGroup section */", coaching_groups + "/* End PBXGroup section */")

# classes group — add coaching
if f"{G_COACHING} /* coaching */" not in text.split("EACA1CDB2E7E49B600C80883 /* classes */")[1].split(");")[0]:
    text = text.replace(
        "\t\t\tEACA1CDA2E7E49B600C80883 /* wrappers */,\n\t\t);\n\t\tpath = classes;",
        f"\t\t\tEACA1CDA2E7E49B600C80883 /* wrappers */,\n\t\t\t{G_COACHING} /* coaching */,\n\t\t);\n\t\tpath = classes;",
    )

# managers — human understanding
text = text.replace(
    "\t\t\tEA56DDA02EC08078000AB522 /* LMPersonDetectionManager.swift */,\n\t\t\tEA4032A12EE077BA002B7A40 /* LMSuggestionBoundBoxManager.swift */,",
    "\t\t\tEA56DDA02EC08078000AB522 /* LMPersonDetectionManager.swift */,\n\t\t\tEA5700002EC10001000AB522 /* LMHumanFrameSnapshot.swift */,\n\t\t\tEA5700022EC10001000AB522 /* LMHumanMaskDerivation.swift */,\n\t\t\tEA5700042EC10001000AB522 /* LMHumanUnderstandingService.swift */,\n\t\t\tEA4032A12EE077BA002B7A40 /* LMSuggestionBoundBoxManager.swift */,",
)

# camera views
text = text.replace(
    "\t\t\tEAFBACBF2E87DE4E00586EC7 /* LMCameraGridOverlayView.swift */,\n\t\t);\n\t\tpath = camera;\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n/* End PBXGroup section */",
    "\t\t\tEAFBACBF2E87DE4E00586EC7 /* LMCameraGridOverlayView.swift */,\n\t\t\tEA5700062EC10001000AB522 /* LMUploadReferenceCardView.swift */,\n\t\t\tEA5700082EC10001000AB522 /* LMAgentIconProvider.swift */,\n\t\t\tEA57000A2EC10001000AB522 /* LMLiquidGlassHUDTokens.swift */,\n\t\t\tEA57000C2EC10001000AB522 /* LMCoachingEdgeLitBar.swift */,\n\t\t\tEA57000E2EC10001000AB522 /* LMCoachingActionPill.swift */,\n\t\t\tEA5700102EC10001000AB522 /* LMCoachingBubbleView.swift */,\n\t\t\tEA5700122EC10001000AB522 /* LMConcentricScoreDonutView.swift */,\n\t\t\tEA5700142EC10001000AB522 /* LMScoreDonutOverlayView.swift */,\n\t\t);\n\t\tpath = camera;\n\t\t\tsourceTree = \"<group>\";\n\t\t};\n/* End PBXGroup section */",
)

# camera pages
text = text.replace(
    "\t\t\tEA56DDBE2EC08E81000AB522 /* LMCameraPage+Session.swift */,\n\t\t\tEACB2E7B2EDC22B700983697 /* LMPhotoPreviewPage.swift */,",
    "\t\t\tEA56DDBE2EC08E81000AB522 /* LMCameraPage+Session.swift */,\n\t\t\tEA5700162EC10001000AB522 /* LMCameraPage+AgentCoaching.swift */,\n\t\t\tEACB2E7B2EDC22B700983697 /* LMPhotoPreviewPage.swift */,",
)

# resources — depth model + config
text = text.replace(
    "\t\t\tEA8629A22EB5A13F00F2B00E /* EVA02.mlpackage */,\n\t\t\tEACA1CE92E7E49B600C80883 /* LaunchScreen.storyboard */,",
    "\t\t\tEA8629A22EB5A13F00F2B00E /* EVA02.mlpackage */,\n\t\t\tEA57003E2EC10001000AB522 /* DepthAnythingV2SmallF16P6.mlpackage */,\n\t\t\t" + G_RES_CONFIG + " /* config */,\n\t\t\tEACA1CE92E7E49B600C80883 /* LaunchScreen.storyboard */,",
)

PBX.write_text(text)
print("PBX groups updated")
