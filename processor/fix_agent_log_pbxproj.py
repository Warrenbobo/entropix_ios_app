#!/usr/bin/env python3
"""Replace broken debug pbxproj entries with properly nested agentLog feature files."""
import re
from pathlib import Path

PBX = Path(__file__).resolve().parent / "processor.xcodeproj/project.pbxproj"

G_COACH_AGENT_LOG = "EA5700662EC10005000AB522"
G_PAGES_AGENT_LOG = "EA5700672EC10005000AB522"

FILES = {
    "LMAgentRequestLogModels.swift": ("EA5700682EC10005000AB522", "EA5700692EC10005000AB522"),
    "LMAgentRequestLogStore.swift": ("EA57006A2EC10005000AB522", "EA57006B2EC10005000AB522"),
    "LMAgentRequestLogRecorder.swift": ("EA57006C2EC10005000AB522", "EA57006D2EC10005000AB522"),
    "LMAgentRequestLogPage.swift": ("EA57006E2EC10005000AB522", "EA57006F2EC10005000AB522"),
    "LMCameraPage+AgentLog.swift": ("EA5700702EC10005000AB522", "EA5700712EC10005000AB522"),
}

OLD_PATTERNS = [
    "LMAgentRequestDebugModels.swift",
    "LMAgentRequestDebugStore.swift",
    "LMAgentRequestDebugRecorder.swift",
    "LMAgentRequestDebugPage.swift",
    "LMCameraPage+AgentDebug.swift",
    "EA57005A2EC10004000AB522",
    "EA57005B2EC10004000AB522",
    "EA57005C2EC10004000AB522",
    "EA57005D2EC10004000AB522",
    "EA57005E2EC10004000AB522",
    "EA57005F2EC10004000AB522",
    "EA5700602EC10004000AB522",
    "EA5700612EC10004000AB522",
    "EA5700622EC10004000AB522",
    "EA5700632EC10004000AB522",
    "EA5700642EC10004000AB522",
    "EA5700652EC10004000AB522",
]


def strip_old_entries(text: str) -> str:
    lines = []
    skip_block = False
    for line in text.splitlines():
        if any(token in line for token in OLD_PATTERNS):
            if "/* debug */ = {" in line and "EA57005" in line:
                skip_block = True
            continue
        if skip_block:
            if line.strip() == "};":
                skip_block = False
            continue
        lines.append(line)
    return "\n".join(lines) + "\n"


def main():
    text = strip_old_entries(PBX.read_text())

    build_entries = []
    file_entries = []
    source_refs = []

    for name, (fid, bid) in FILES.items():
        if f"/* {name} */" in text:
            print(f"already present: {name}")
            continue
        path_attr = f'path = "{name}";' if "+" in name else f"path = {name};"
        build_entries.append(
            f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};"
        )
        file_entries.append(
            f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; {path_attr} sourceTree = \"<group>\"; }};"
        )
        source_refs.append(f"\t\t\t\t{bid} /* {name} in Sources */,")

    if build_entries:
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

    if G_COACH_AGENT_LOG not in text:
        coach_group = f"""
\t\t{G_COACH_AGENT_LOG} /* agentLog */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tEA5700682EC10005000AB522 /* LMAgentRequestLogModels.swift */,
\t\t\t\tEA57006A2EC10005000AB522 /* LMAgentRequestLogStore.swift */,
\t\t\t\tEA57006C2EC10005000AB522 /* LMAgentRequestLogRecorder.swift */,
\t\t\t);
\t\t\tpath = agentLog;
\t\t\tsourceTree = "<group>";
\t\t}};
"""
        text = text.replace("/* End PBXGroup section */", coach_group + "/* End PBXGroup section */")
        text = text.replace(
            "\t\t\tEA5700562EC10002000AB522 /* managers */,\n\t\t);\n\t\tpath = coaching;",
            f"\t\t\tEA5700562EC10002000AB522 /* managers */,\n\t\t\t{G_COACH_AGENT_LOG} /* agentLog */,\n\t\t);\n\t\tpath = coaching;",
        )

    if G_PAGES_AGENT_LOG not in text:
        pages_group = f"""
\t\t{G_PAGES_AGENT_LOG} /* agentLog */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tEA57006E2EC10005000AB522 /* LMAgentRequestLogPage.swift */,
\t\t\t);
\t\t\tpath = agentLog;
\t\t\tsourceTree = "<group>";
\t\t}};
"""
        text = text.replace("/* End PBXGroup section */", pages_group + "/* End PBXGroup section */")
        text = text.replace(
            "\t\t\tEACA1D0B2E7E504F00C80883 /* LMWebViewPage.swift */,\n\t\t);\n\t\tpath = pages;",
            f"\t\t\tEACA1D0B2E7E504F00C80883 /* LMWebViewPage.swift */,\n\t\t\t{G_PAGES_AGENT_LOG} /* agentLog */,\n\t\t);\n\t\tpath = pages;",
        )

    if "LMCameraPage+AgentLog.swift" not in text.split("EACA1D0E2E7E517400C80883 /* camera */")[1].split(");")[0]:
        text = text.replace(
            "\t\t\tEA5700162EC10001000AB522 /* LMCameraPage+AgentCoaching.swift */,\n\t\t\tEACB2E7B2EDC22B700983697 /* LMPhotoPreviewPage.swift */,",
            "\t\t\tEA5700162EC10001000AB522 /* LMCameraPage+AgentCoaching.swift */,\n\t\t\tEA5700702EC10005000AB522 /* LMCameraPage+AgentLog.swift */,\n\t\t\tEACB2E7B2EDC22B700983697 /* LMPhotoPreviewPage.swift */,",
        )

    PBX.write_text(text)
    print("agentLog files wired into pbxproj")


if __name__ == "__main__":
    main()
