-- A mid-game fixture: a known board plus preset score/moves.
return {
    loader = "board",
    data = {
        score = 40,
        moves = 5,
        grid = {
            { 1, 3, 1, 2, 3, 4 },
            { 2, 4, 1, 3, 4, 2 },
            { 3, 2, 2, 1, 2, 3 },
            { 4, 1, 1, 2, 1, 4 },
            { 1, 3, 4, 3, 2, 1 },
            { 2, 4, 2, 4, 3, 2 },
        },
    },
}
