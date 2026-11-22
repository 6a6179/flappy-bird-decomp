// Commands queued by the native frame and consumed by dot_EAGLView.
#pragma once

enum ViewCommand {
    ReportScore = 0,
    ShowLeaderboard = 1,
    OpenAppStore = 2,
    CopyrightTapped = 3,
    ShareScore = 4,
    ConfigureTitle = 6,
    RoundStarted = 7,
    RoundEnded = 8,
    PlayPoint = 9,
    PlaySwoosh = 10,
    PlayDie = 11,
    PlayHit = 12,
    PlayWing = 13
};
