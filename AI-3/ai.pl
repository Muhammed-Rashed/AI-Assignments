% --- Imports ---
:- consult('move.pl').

% Get a valid move
get_valid_move(Board, R1, C1, R2, C2, Type, NewBoard) :-
    nth0(R1, Board, Row),
    nth0(C1, Row, Piece),

    (   % Horizontal moves: same row, different column
        between(0, 10, C2), C1 \= C2, R2 = R1
    ;   % Vertical moves: same column, different row
        between(0, 10, R2), R1 \= R2, C2 = C1
    ),

    is_turn_piece(Piece, Type),

    valid_move(Board, R1, C1, R2, C2, Piece, Type),

    move(Board, R1, C1, R2, C2, Piece, NewBoard).

% Helper to sort and limit moves to the top Limit
limit_moves(Board, RawMoves, Type, Limit, LimitedMoves) :-
    findall(Score-Move, (
        member(Move, RawMoves),
        Move = (R1, C1, R2, C2),

        % Simulate move to get immediate utility
        get_piece(Board, R1, C1, Piece),
        move(Board, R1, C1, R2, C2, Piece, TempBoard),
        utility(TempBoard, RawScore),

        % If Max player (a), negate score because keysort is ascending
        (Type = a -> Score is -1 * RawScore ; Score = RawScore)
    ), ScoredMoves),
    keysort(ScoredMoves, Sorted),
    extract_top_n(Sorted, Limit, LimitedMoves).

extract_top_n([], _, []).
extract_top_n(_, 0, []) :- !.
extract_top_n([_-Move | T], N, [Move | Rest]) :- 
    N1 is N - 1,
    extract_top_n(T, N1, Rest).

% Base case (Leaf node or limit reached)
alphabeta(Board, _, _, _, 0, _, Type, UVal) :-
    !,
    utility(Board, UVal).

% Alpha-Beta pruning
alphabeta(Board, Alpha, Beta, BestPos, Depth, Width, Type, UVal) :-
    Depth > 0,
    % Make a list of valid moves
    findall((R1, C1, R2, C2), get_valid_move(Board, R1, C1, R2, C2, Type, _), ValidMoves),

    limit_moves(Board, ValidMoves, Type, Width, TopValidMoves),

    % Get the best move in the ValidMoves list
    bestMove(Board, TopValidMoves, Alpha, Beta, BestMove, Depth, Width, Type, UVal),

    generate_board(Board, BestMove, Type, BestPos).


% Prune if Alpha and Beta overlapped
bestMove(Board, [_|_], Alpha, Beta, _, _, _, Type, UVal) :-
    Alpha >= Beta,
    !,
    (Type = a -> UVal is Beta ; UVal is Alpha).

% Stop the recursion of only one move is left
bestMove(Board, [Move], Alpha, Beta, Move, Depth, Width, Type, UVal):-
    UpdatedDepth is Depth - 1,

    switch(Type, NewType),

    % Generate a board with all the moves played for the best move
    generate_board(Board, Move, Type, NewBoard),

    % Explore more depth
    alphabeta(NewBoard, Alpha, Beta, _, UpdatedDepth, Width, NewType, UVal).

% Recurse to find the best move
bestMove(Board, [Move | RestOfMoves], Alpha, Beta, BestMove, Depth, Width, Type, BestUVal) :-
    UpdatedDepth is Depth - 1,

    switch(Type, NewType),

    % Simulate playing Move
    generate_board(Board, Move, Type, NewBoard),

    % Explore more depth
    alphabeta(NewBoard, Alpha, Beta, _, UpdatedDepth, Width, NewType, UVal),

    % Update Alpha and Beta
    updateValues(UVal, Alpha, Beta, NewAlpha, NewBeta, Type),

    % Explore the rest of moves in the list
    bestMove(Board, RestOfMoves, NewAlpha, NewBeta, Move2, Depth, Width, Type, UVal2),

    % Compare current move with the best one found so far
    betterOf(Move, UVal, Move2, UVal2, BestMove, BestUVal, Type).

generate_board(Board, Move, Type, FinalBoard) :-
    Move = (R1, C1, R2, C2),
    get_piece(Board, R1, C1, Piece),
    move(Board, R1, C1, R2, C2, Piece, FinalBoard).

% Update Alpha when player is max
updateValues(UVal, Alpha, Beta, NewAlpha, Beta, a):-
    (UVal > Alpha -> NewAlpha is UVal ; NewAlpha is Alpha).

% Update Beta when player is min
updateValues(UVal, Alpha, Beta, Alpha, NewBeta, d):-
    (UVal < Beta -> NewBeta is UVal ; NewBeta is Beta).

% Choose move with max UVal
betterOf(Move1, UVal1, Move2, UVal2, BestMove, BestUVal, a) :-
    (UVal1 >= UVal2 -> (BestMove = Move1, BestUVal is UVal1)
    ; (BestMove = Move2, BestUVal is UVal2)
    ).

% Choose move with min UVal
betterOf(Move1, UVal1, Move2, UVal2, BestMove, BestUVal, d) :-
    (UVal1 =< UVal2 -> (BestMove = Move1, BestUVal is UVal1)
    ; (BestMove = Move2, BestUVal is UVal2)
    ).

% ======= Utility Function =======
% attackers -> max, defenders -> min
% UVal =
%    (AttackersAroundKing)^3                     // King in danger
%  + 20 (If AttackersAroundKing =:= 3)            // King in much more danger
%  + 0.3 * (InitialDefenders - CurrentDefenders) // The amount of defenders captured
%  + 700 (If AttackersAroundKing =:= 4)           // Attackers won
%  - 0.3 * (InitialAttackers - CurrentAttackers) // The amount of attackers captured
%  - 2 * (KingOpenEdgePaths)                     // The number of edges the king can reach in one move (The king can't reach corners without reaching edges)
%  - (4 * KingOpenCornerPaths)^3                 // The number of corners the king can reach in one move (max is 2 corners)
%  - 700 (If KingOnCorner = true)                 // Defenders won

utility(Board, UVal) :-
    % Get the number of attackers around the king
    get_piece(Board, R, C, k),
    findall((R2,C2), adjacent(R,C,R2,C2), Adj),
    count_blocked(Board, Adj, DangerCount),
    CubedDangerCount is DangerCount ^ 3,
    % If 3 attackers add 20 to show more danger
    ((DangerCount =:= 3) -> FinalDangerCount is CubedDangerCount + 20 ;
                        FinalDangerCount is CubedDangerCount),

    % Get captured attackers
    count_piece(Board, a, RemainingAttackers),
    CapturedAttackers is 24 - RemainingAttackers,
    
    % Check if hte king is already captured (surrounded by 4 attackers)
    (king_captured(Board) -> IsCaptured = 1 ; IsCaptured = 0),

    % Get captured defenders
    count_piece(Board, d, RemainingDefenders),
    CapturedDefenders is 12 - RemainingDefenders,

    % Get the number of edges and corners the king can reach
    king_mobility(Board, Edges, Corners),

    % Check if the king has escaped (on a corner)
    (king_escaped(Board) -> IsEscaped = 1 ; IsEscaped = 0),

    UVal is FinalDangerCount + 0.3*CapturedDefenders + 700*IsCaptured - 0.3*CapturedAttackers - 2*Edges - (4*Corners)^3 - 700*IsEscaped.

% Count a type in the board
count_piece(Board, Piece, Count) :-
    count_row(Board, Piece, 0, Count).

count_row([], _, Acc, Acc).
count_row([Row|Rest], Piece, Acc, Count) :-
    count_in_row(Row, Piece, RowCount),
    NewAcc is Acc + RowCount,
    count_row(Rest, Piece, NewAcc, Count).

count_in_row([], _, 0).
count_in_row([Piece|Rest], Piece, Count) :-
    !,
    count_in_row(Rest, Piece, NewCount),
    Count is NewCount + 1.

count_in_row([_|Rest], Piece, Count) :-
    count_in_row(Rest, Piece, Count).


% Get the number of edges and corners that the king can move to
king_mobility(Board, Edges, Corners) :-
    % Get the location of the king
    get_piece(Board, R, C, k),
    
    % Find all edges that the king can reach
    findall((R2, C2),
        (valid_move(Board, R, C, R2, C2, k, d), edge(R2, C2)), Moves1),
    length(Moves1, Edges),
    
    % Find all corners that the king can reach
    findall((R2, C2),
        (valid_move(Board, R, C, R2, C2, k, d), corner(R2, C2)),Moves2),
    length(Moves2, Corners).