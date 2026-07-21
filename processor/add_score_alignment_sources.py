#!/usr/bin/env python3
"""Add PiDiNet/U2Netp resources and new score-alignment Swift sources to processor.xcodeproj."""
import uuid
from pathlib import Path

PBX = Path(__file__).resolve().parent / "processor.xcodeproj/project.pbxproj"

NEW_SWIFT = [
    "LMPidinetModelProvider.swift",
    "LMU2NetpModelProvider.swift",
    "LMOpenCvLineDetector.swift",
    "LMSubjectMaskAnalyzer.swift",
    "LMDepthLayeringScorer.swift",
]

NEW_RESOURCES = [
    ("PiDiNet.mlpackage", "folder.mlpackage"),
    ("U2Netp.mlpackage", "folder.mlpackage"),
]


def gen_id():
    return uuid.uuid4().hex[:24].upper()


def main():
    text = PBX.read_text()
    build_entries = []
    file_entries = []
    source_refs = []
    resource_refs = []
    group_refs = []

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
        group_refs.append((fid, name))

    # mlpackages go in Sources like DepthAnything / EVA02 (Compile Sources)
    for name, ftype in NEW_RESOURCES:
        if f"path = {name};" in text:
            print(f"skip {name}")
            continue
        fid, bid = gen_id(), gen_id()
        build_entries.append(
            f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};"
        )
        file_entries.append(
            f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {name}; sourceTree = \"<group>\"; }};"
        )
        source_refs.append(f"\t\t\t\t{bid} /* {name} in Sources */,")
        group_refs.append((fid, name))

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
        "/* Begin PBXSourcesBuildPhase section */\n\t\tEACA1BED2E7E408900C80883 /* Sources */ = {\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n"
        + "\n".join(source_refs)
        + "\n",
        1,
    )

    # Add mlpackages next to DepthAnything in resources group
    for fid, name in group_refs:
        if name.endswith(".mlpackage"):
            needle = "EA57003E2EC10001000AB522 /* DepthAnythingV2SmallF16P6.mlpackage */,\n"
            insert = needle + f"\t\t\t\t{fid} /* {name} */,\n"
            if needle in text and f"{fid} /* {name} */" not in text:
                text = text.replace(needle, insert, 1)
        elif name in (
            "LMPidinetModelProvider.swift",
            "LMU2NetpModelProvider.swift",
        ):
            needle = "204E896C532D4BD4BF996103 /* LMEVA02ModelProvider.swift */,\n"
            insert = needle + f"\t\t\t\t{fid} /* {name} */,\n"
            if needle in text and f"{fid} /* {name} */" not in text:
                text = text.replace(needle, insert, 1)
        elif name == "LMOpenCvLineDetector.swift":
            needle = "EA5700242EC10001000AB522 /* LMGeometricScorer.swift */,\n"
            insert = needle + f"\t\t\t\t{fid} /* {name} */,\n"
            if needle in text and f"{fid} /* {name} */" not in text:
                text = text.replace(needle, insert, 1)
        elif name in ("LMSubjectMaskAnalyzer.swift", "LMDepthLayeringScorer.swift"):
            needle = "EA5700242EC10001000AB522 /* LMGeometricScorer.swift */,\n"
            insert = needle + f"\t\t\t\t{fid} /* {name} */,\n"
            if needle in text and f"{fid} /* {name} */" not in text:
                text = text.replace(needle, insert, 1)

    PBX.write_text(text)
    print(f"Added {len(build_entries)} files")


if __name__ == "__main__":
    main()
