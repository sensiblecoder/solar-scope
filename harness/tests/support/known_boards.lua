-- Known board layouts for deterministic tests (no pre-existing matches).
return {
    -- Swapping (3,3)<->(3,4) turns column 3 into a run of four 1s.
    col3_swap = {
        { 1, 3, 1, 2, 3, 4 },
        { 2, 4, 1, 3, 4, 2 },
        { 3, 2, 2, 1, 2, 3 },
        { 4, 1, 1, 2, 1, 4 },
        { 1, 3, 4, 3, 2, 1 },
        { 2, 4, 2, 4, 3, 2 },
    },
}
