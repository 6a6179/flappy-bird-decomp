"""Compiler inputs for the editable Google Mobile Ads SDK."""

from pathlib import Path


SOURCE = Path(__file__).resolve().parents[1] / "src"
THUMB = {"gad_adapter_html", "gad_adapter_iad", "gad_rendered_checker"}
UNOPTIMIZED = {"ad_transform", "gad_simple_wire_format", "gad_visibility", "GTMStackTrace"}
UPSTREAM_NAMES = {
    "GTMStackTrace": "GAD_GTMStackTrace",
    "GTMStringEncoding": "GAD_GTMStringEncoding",
    "SBJSON": "GAD_SBJSON",
}

# The matching sources synthesize these accessors twice. The editable build
# takes both halves of each property from its class implementation on both CPUs.
METHOD_OWNERS = {
    "-[GADBannerView slot]": SOURCE / "gad_banner.m",
    "-[GADBannerView setSlot:]": SOURCE / "gad_banner.m",
    "-[GADImpressionTicketGestureRecognizer vars]": SOURCE / "gad_ticket_gesture.m",
    "-[GADImpressionTicketGestureRecognizer setVars:]": SOURCE / "gad_ticket_gesture.m",
    "-[GADImpressionTicketGestureRecognizerPrivate distanceMoved]": SOURCE / "gad_ticket_gesture.m",
    "-[GADImpressionTicketGestureRecognizerPrivate setDistanceMoved:]": SOURCE / "gad_ticket_gesture.m",
    "-[GADImpressionTicketGestureRecognizerPrivate gestureState]": SOURCE / "gad_ticket_gesture.m",
    "-[GADImpressionTicketGestureRecognizerPrivate setGestureState:]": SOURCE / "gad_ticket_gesture.m",
    "-[GADSharedStatistics sequenceNumber]": SOURCE / "gad_statistics.m",
    "-[GADSharedStatistics setSequenceNumber:]": SOURCE / "gad_statistics.m",
}


def sources(sdk):
    """Return each AdMob translation unit and its Clang flags for either ARM slice."""
    paths = sorted(SOURCE.glob("gad_*.m")) + sorted(SOURCE.glob("gad_*.c"))
    paths.extend(SOURCE / name for name in (
        "ad_transform.c", "connection_support.m", "library_admob.m", "library_admob_sdk.m",
        "library_connection.m", "editable_admob_data.m", "editable_admob_runtime.m",
    ))
    paths.extend(SOURCE / "library_upstream" / (name + ".m") for name in UPSTREAM_NAMES)
    jobs = []
    for path in paths:
        flags = ["-std=gnu99", "-isysroot", str(sdk)]
        if path.stem not in THUMB:
            flags.append("-marm")
        if path.stem in UNOPTIMIZED or path.stem.startswith("gad_gesture_"):
            flags.append("-O0")
        if path.suffix == ".m":
            flags.extend(["-fno-objc-arc", "-fobjc-exceptions", "-Wno-incomplete-implementation"])
        if path.stem in UPSTREAM_NAMES:
            flags.append(f"-D{path.stem}={UPSTREAM_NAMES[path.stem]}")
        jobs.append((path, flags))
    return jobs
